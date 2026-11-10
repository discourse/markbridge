# frozen_string_literal: true

require "nokogiri"
require "uri"
require_relative "ast_dump"
require_relative "ast_shrinker"
require_relative "markdown_it_cooker"

# Renders an AST, cooks the Markdown with markdown-it set up like Discourse
# and compares the cooked HTML with the AST. Asserting on the Markdown string alone lets a
# wrong indentation or a lost blank line pass unnoticed: the string still
# looks plausible while a CommonMark parser reads something else.
#
# Four checks, each one a Failure of its own:
# - structure: the skeleton of the cooked DOM (lists, items, quotes, code,
#   links, emphasis, headings) is the skeleton of the AST
# - text: the visible text of the cooked HTML is the text of the AST, with
#   whitespace runs collapsed, image alt text and code text counted. This
#   catches swallowed or leaked markup whatever the structure looks like.
# - links: the link and image destinations of the cooked HTML are those of
#   the AST
# - lists: a list whose items hold inline content only cooks tight, with
#   no <p> in its items
#
# Discourse BBCode the renderer writes ([u], [spoiler], [details]) is text
# to plain markdown-it, and the text check expects it as text.
#
# A table the renderer cannot write as a Markdown table is HTML, and
# everything in it is written in html_mode: HTML tags for emphasis, lists
# and code, a span for a spoiler, no BBCode. The renderer decides
# that per table, and the checker reads the decision off the table tag
# (see RecordingTableTag) rather than guessing it again: both forms are
# right, the checks only need to know which one to expect.
#
# A fifth, normalizer, comes first: the AST has to be one the default
# normalizer leaves alone, so the tree that is rendered is the tree the
# expectation reads.
class RoundTripChecker
  AST = Markbridge::AST

  Failure = Data.define(:check, :message)

  # Which parent a node of these classes needs, and which children the
  # parent takes. The generators build nothing else, and the shrinker
  # must not either: a table with text in it is no case.
  SHAPES = {
    AST::ListItem => AST::List,
    AST::TableRow => AST::Table,
    AST::TableCell => AST::TableRow,
  }.freeze

  # HTML elements that carry structure. Everything else (p, span, br,
  # input, comments) adds no node to the skeleton and its children move up
  # to the parent.
  STRUCTURAL_ELEMENTS = %w[
    ul
    ol
    li
    blockquote
    pre
    code
    strong
    em
    a
    img
    h1
    h2
    h3
    h4
    h5
    h6
    hr
    div
    s
    sup
    sub
    ins
    del
    mark
    table
    tr
    th
    td
  ].freeze

  # Elements whose content stands apart from the text around them, so the
  # text check puts a separator on both sides.
  BLOCK_ELEMENTS = %w[
    p
    div
    li
    ul
    ol
    blockquote
    pre
    h1
    h2
    h3
    h4
    h5
    h6
    hr
    br
    table
    thead
    tbody
    tr
    td
    th
    details
    summary
  ].freeze

  # AST nodes the renderer writes with blank lines around them. A list
  # item with one of these next to other content is loose on purpose.
  # A nested List is not among them: the renderer attaches it to the
  # content in front of it and keeps the item tight.
  BLANK_LINE_NODES = [
    AST::Paragraph,
    AST::Quote,
    AST::Heading,
    AST::Align,
    AST::HorizontalRule,
    AST::Table,
    AST::Details,
    AST::Poll,
    AST::Event,
  ].freeze

  # Nodes whose content is apart from the text around them, for the text
  # check. Same idea as BLOCK_ELEMENTS on the AST side.
  BLOCK_NODES =
    (
      BLANK_LINE_NODES + [AST::List, AST::ListItem, AST::TableRow, AST::TableCell, AST::LineBreak]
    ).freeze

  # Containers the renderer writes also when nothing visible is in them:
  # an empty div, heading, sup or sub.
  ALWAYS_WRITTEN = [
    AST::Align,
    AST::Heading,
    AST::Superscript,
    AST::Subscript,
    AST::Insertion,
    AST::Deletion,
    AST::Highlight,
  ].freeze

  # Schemes the renderer links (see UrlTag). Anything else that looks like
  # a scheme is dropped, a scheme-less href passes.
  LINKABLE_SCHEME = /\A(?:https?|ftps?|mailto):/i
  SCHEME_LIKE = /\A[a-z][a-z0-9+.-]*:/i

  # The table tag, remembering which tables it wrote as HTML.
  class RecordingTableTag < Markbridge::Renderers::Discourse::Tags::TableTag
    HTML_START = /\A\s*<table>/

    # @return [Hash{Markbridge::AST::Table => Boolean}]
    attr_reader :html_tables

    def initialize
      super
      @html_tables = {}.compare_by_identity
    end

    def render(element, interface)
      output = super
      @html_tables[element] = output.match?(HTML_START)
      output
    end
  end

  # The plugin features the checker renders with when none are given.
  DEFAULT_FEATURES = { details: true, spoiler: true, bbcode: false }.freeze

  # @param features [Hash{Symbol => Boolean}, nil] the plugin features of
  #   the target site, see +Markbridge.discourse_renderer+. The expected
  #   text follows them: the BBCode of a plugin is text to plain
  #   markdown-it, the plain form without the plugin cooks. With bbcode
  #   on, the sizes of the generator are written as they are.
  # @param cooker [#cook, #cooks?] what cooks the Markdown:
  #   MarkdownItCooker, or a profile of DiscourseEngineCooker, which
  #   cooks the BBCode of the plugins it has into their HTML
  def initialize(features: nil, cooker: MarkdownItCooker)
    @features = DEFAULT_FEATURES.merge(features || {})
    @cooker = cooker
    @link_depth = 0
    @islands = 0
    @table_tag = RecordingTableTag.new
    library = Markbridge::Renderers::Discourse::TagLibrary.default
    library.register(AST::Table, @table_tag)
    sizes = ->(size) { size } if @features[:bbcode]
    @renderer = Markbridge.discourse_renderer(tag_library: library, features: @features, sizes:)
  end

  # @param document [Markbridge::AST::Document]
  # @return [Array<Failure>] empty when the document round-trips
  def failures(document)
    violations = Markbridge::Normalizer.shared_default.violations(document)
    unless violations.empty?
      return [
        Failure.new(
          check: :normalizer,
          message: "the normalizer would rewrite the tree: #{violations.inspect}",
        ),
      ]
    end

    misplaced = misplaced_node(document)
    if misplaced
      return [
        Failure.new(
          check: :shape,
          message: "#{AstDump.describe(misplaced)} is not where it belongs",
        ),
      ]
    end

    markdown = render(document)
    fragment = Nokogiri::HTML5.fragment(cook(markdown))

    failures = []
    failures << check_structure(document, fragment)
    failures << check_text(document, fragment)
    failures << check_links(document, fragment)
    failures << check_lists(document, fragment)
    failures.compact
  end

  # Shrinks +document+ (in place) as long as one of the checks that fail
  # now keeps failing, then returns the report for what is left.
  #
  # @param document [Markbridge::AST::Document] a document that fails
  # @param label [String] what the report is about, for example a seed
  # @return [String]
  def explain(document, label:)
    before = document.descendants.size
    shrink(document)
    after = document.descendants.size

    label = "#{label}, shrunk from #{before} to #{after} nodes" if after < before
    report(document, label:)
  end

  # Shrinks +document+ in place as long as one of the checks that fail
  # now keeps failing. A candidate the renderer raises on does not count
  # as failing.
  #
  # @param document [Markbridge::AST::Document] a document that fails
  # @return [Markbridge::AST::Document] the same document
  def shrink(document)
    checks = failures(document).map(&:check)
    AstShrinker.shrink(document) do |candidate|
      failures(candidate).map(&:check).intersect?(checks)
    rescue StandardError
      false
    end
  end

  # The AST, its Markdown, the cooked HTML and the failures.
  #
  # @param document [Markbridge::AST::Document]
  # @param label [String]
  # @return [String]
  def report(document, label:)
    markdown = render(document)
    parts = [label, "", "AST:", AstDump.dump(document), "", "Markdown:", markdown]
    parts << "" << "Cooked:" << cook(markdown)
    failures(document).each { |failure| parts << "" << "#{failure.check}: #{failure.message}" }
    parts.join("\n")
  end

  private

  # Without the normalizer: {#failures} has checked that it would change
  # nothing, and it drops an emptied element in place, which would take
  # the tree out from under the shrinker's undo.
  #
  # @param document [Markbridge::AST::Document]
  # @return [String]
  def render(document)
    Markbridge.render(document, renderer: @renderer, normalize: false).markdown
  end

  # Whether the renderer wrote +table+ as HTML in the last render.
  def html_table?(table)
    @table_tag.html_tables.fetch(table, false)
  end

  # @param markdown [String]
  # @return [String]
  def cook(markdown)
    @cooker.cook(markdown)
  end

  def check_structure(document, fragment)
    expected = expected_skeleton(document)
    actual = actual_skeleton(fragment.children)
    return if expected == actual

    Failure.new(
      check: :structure,
      message:
        "expected the structure\n#{format_skeleton(expected)}\nbut the cooked HTML has\n#{format_skeleton(actual)}",
    )
  end

  def check_text(document, fragment)
    expected = normalize_text(expected_text(document, +""))
    actual = normalize_text(cooked_text(fragment, +""))
    return if expected == actual

    Failure.new(
      check: :text,
      message: "expected the text #{expected.inspect}\nbut got #{actual.inspect}",
    )
  end

  # Discourse keeps the short URL of an upload it cannot resolve in
  # data-orig-src or data-orig-href, and its heading anchors are no links
  # of the document.
  def check_links(document, fragment)
    expected = expected_links(document).sort
    actual =
      fragment
        .css("a[href], img[src]")
        .reject { |node| anchor?(node) }
        .map do |node|
          decode(node["data-orig-href"] || node["href"] || node["data-orig-src"] || node["src"])
        end
        .sort
    return if expected == actual

    Failure.new(
      check: :links,
      message: "expected the links #{expected.inspect}\nbut got #{actual.inspect}",
    )
  end

  # Lists are paired by document order. When the counts differ the
  # structure check reports it, and there is nothing to pair.
  def check_lists(document, fragment)
    lists = document.descendants(AST::List)
    elements = fragment.css("ul, ol")
    return unless lists.size == elements.size

    lists
      .zip(elements)
      .each_with_index do |(list, element), index|
        next if may_be_loose?(list)

        loose = element.xpath("./li[p]")
        next if loose.empty?

        return(
          Failure.new(
            check: :lists,
            message:
              "list #{index + 1} holds inline content only but cooks loose, " \
                "its item #{loose.first.to_html.inspect} got a <p>",
          )
        )
      end
    nil
  end

  # The first node that sits under the wrong parent, or holds a child
  # that belongs elsewhere.
  def misplaced_node(document)
    [document, *document.descendants(AST::Element)].each do |node|
      misplaced = node.children.find { |child| misplaced?(child, node) }
      return misplaced if misplaced
    end
    nil
  end

  def misplaced?(child, parent)
    needed = SHAPES[child.class]
    return !parent.is_a?(needed) if needed

    SHAPES.values.any? { |container| parent.is_a?(container) }
  end

  # One skeleton node. The same shape is built from the AST and from the
  # DOM so the two can be compared with a plain ==. strong inside em and
  # em inside strong cook the same (`***x***` is em(strong(x)) to
  # markdown-it), so an em with a strong as its only child is turned
  # around and strong is outside.
  def skeleton(name, children: [], text: nil, href: nil)
    if name == "em" && children.size == 1 && children.first[:name] == "strong"
      inner = children.first
      return(
        {
          name: "strong",
          children: [{ name: "em", children: inner[:children], text: nil, href: nil }],
          text:,
          href:,
        }
      )
    end

    { name:, children:, text:, href: }
  end

  # @param node [Markbridge::AST::Node]
  # @param html [Boolean] whether the node is written in html_mode
  # @return [Array<Hash>] the skeleton nodes this AST node stands for.
  #   Document, Paragraph, Text and LineBreak add no node of their own,
  #   their content moves up to the parent. A container with nothing
  #   visible in it renders to nothing and adds no node either.
  def expected_skeleton(node, html: false)
    return [] if node.is_a?(AST::Element) && !visible?(node)

    case node
    when AST::List
      [skeleton(node.ordered? ? "ol" : "ul", children: expected_children(node, html:))]
    when AST::ListItem
      [skeleton("li", children: expected_children(node, html:))]
    when AST::Quote
      # The BBCode of an attributed quote is text to plain markdown-it,
      # the content stands on its own. In html_mode the quote is a
      # blockquote without attribution.
      if bbcode_quote?(node) && !html && !@cooker.cooks?(:quote)
        expected_children(node, html:)
      else
        [skeleton("blockquote", children: expected_children(node, html:))]
      end
    when AST::Code
      [expected_code(node)]
    when AST::Url
      expected_link(node, html:)
    when AST::Email
      if node.address
        children = inside_link { expected_children(node, html:) }
        [skeleton("a", children:, href: "mailto:#{node.address}")]
      else
        expected_children(node, html:)
      end
    when AST::Image
      [skeleton("img", href: node.src)]
    when AST::Heading
      [skeleton("h#{node.level}", children: expected_children(node, html:))]
    when AST::Align
      [skeleton("div", children: expected_children(node, html:))]
    when AST::Superscript
      [skeleton("sup", children: expected_children(node, html:))]
    when AST::Subscript
      [skeleton("sub", children: expected_children(node, html:))]
    when AST::Insertion
      [skeleton("ins", children: expected_children(node, html:))]
    when AST::Deletion
      [skeleton("del", children: expected_children(node, html:))]
    when AST::Highlight
      [skeleton("mark", children: expected_children(node, html:))]
    when AST::Table
      [expected_table(node)]
    when AST::Upload
      expected_upload(node, html:)
    when AST::MarkdownText
      # In a table the renderer writes as HTML, pre-formatted Markdown is
      # an island inside a <div>, see Renderer#render_markdown_text.
      return [] unless html

      @islands += 1
      [skeleton("div")]
    when AST::Paragraph
      # In html_mode a paragraph with a Markdown island in it is a <div>,
      # because a <p> cannot hold the <div> of the island.
      before = @islands
      children = expected_children(node, html:)
      html && @islands > before ? [skeleton("div", children:)] : children
    when AST::Bold
      [skeleton("strong", children: expected_children(node, html:))]
    when AST::Italic
      [skeleton("em", children: expected_children(node, html:))]
    when AST::Strikethrough
      [skeleton("s", children: expected_children(node, html:))]
    when AST::HorizontalRule
      [skeleton("hr")]
    when AST::Details
      return expected_children(node, html:) if @features[:details]

      # Without the plugin the title is a paragraph in bold in front, and
      # in html_mode a div holds both.
      title = details_title(node) ? [skeleton("strong")] : []
      if html
        [skeleton("div", children: title + expected_children(node, html:))]
      else
        title + expected_children(node, html:)
      end
    when AST::Element
      expected_children(node, html:)
    else
      []
    end
  end

  def expected_children(element, html: false)
    element.children.flat_map { |child| expected_skeleton(child, html:) }
  end

  # Whether the node puts something on the page. Whitespace-only text
  # does not: the postprocessor clears a line of whitespace, and a
  # wrapper around whitespace loses its markers. A bare link shows its
  # href, a link without visible text shows it too. A table with a cell
  # is drawn whatever the cell holds.
  def visible?(node)
    case node
    when AST::Text, AST::MarkdownText
      node.text.match?(/[^[:space:]]/)
    when AST::Image, AST::HorizontalRule, AST::Mention, AST::Upload, *ALWAYS_WRITTEN
      true
    when AST::Code
      !code_text(node).empty?
    when AST::Url
      linkable?(node.href) || node.children.any? { |child| visible?(child) }
    when AST::Email
      !node.address.nil? || node.children.any? { |child| visible?(child) }
    when AST::Table
      node.descendants.any?(AST::TableCell)
    when AST::Element
      node.children.any? { |child| visible?(child) }
    else
      false
    end
  end

  # In a Markdown table the renderer takes the first row whose cells are
  # all header cells as the header row, or the first row, and a Markdown
  # table always has one. An HTML table keeps every cell as it is, and
  # its content is written in html_mode. A row without cells is dropped.
  def expected_table(node)
    html = html_table?(node)
    rows =
      node.children.select { |row| row.is_a?(AST::TableRow) && row.children.any?(AST::TableCell) }
    header =
      rows.index do |row|
        row.children.all? { |cell| !cell.is_a?(AST::TableCell) || cell.header? }
      end || 0

    skeleton(
      "table",
      children:
        rows.each_with_index.map do |row, index|
          cells = row.children.select { |cell| cell.is_a?(AST::TableCell) }
          skeleton(
            "tr",
            children:
              cells.map do |cell|
                header_cell = html ? cell.header? : index == header
                skeleton(header_cell ? "th" : "td", children: expected_children(cell, html:))
              end,
          )
        end,
    )
  end

  # An upload is an image or a link to a file, see UploadTag. In a table
  # the renderer writes as HTML it is a Markdown island inside a <div>.
  # Inside a link label a file attachment is its name, a link cannot
  # hold a link.
  def expected_upload(node, html: false)
    return [] if attachment_name?(node)

    destination = upload_destination(node)
    upload =
      if node.type == :image
        skeleton("img", href: destination)
      else
        skeleton("a", href: destination)
      end
    return [upload] unless html

    @islands += 1
    [skeleton("div", children: [upload])]
  end

  # Whether the renderer writes +node+ as its file name: a file
  # attachment inside a link label.
  def attachment_name?(node)
    node.is_a?(AST::Upload) && node.type == :attachment && node.raw.nil? && in_link?
  end

  def upload_destination(node)
    "upload://#{node.filename || node.sha1}"
  end

  # A link with an href the renderer refuses keeps only its text.
  def expected_link(node, html: false)
    return expected_children(node, html:) unless linkable?(node.href)

    children = inside_link { expected_children(node, html:) }
    [skeleton("a", children:, href: node.href)]
  end

  # Runs the block for the content of a link label, where a file
  # attachment is its name, see #expected_upload.
  def inside_link
    @link_depth += 1
    yield
  ensure
    @link_depth -= 1
  end

  def in_link?
    @link_depth.positive?
  end

  # A code element prints as a fenced block when its block flag is set or
  # its text spans more than one line; otherwise it stays a code span.
  def expected_code(node)
    text = code_text(node)

    # One newline at the end of block code is the one in front of the
    # closing fence, so it does not show up in the cooked code.
    block_code?(node) ? skeleton("pre", text: text.chomp) : skeleton("code", text:)
  end

  def code_text(node)
    node.descendants(AST::Text).map(&:text).join
  end

  def block_code?(node)
    node.block || code_text(node).include?("\n")
  end

  def linkable?(href)
    return false if href.nil? || href.empty?
    return true if href.match?(LINKABLE_SCHEME)

    !href.match?(SCHEME_LIKE)
  end

  # @param nodes [Nokogiri::XML::NodeSet]
  # @return [Array<Hash>]
  def actual_skeleton(nodes)
    nodes.flat_map do |node|
      next [] unless node.element?

      case node.name
      when "pre"
        # markdown-it puts the code in a <code> child and end it with a
        # newline that the source does not have.
        [skeleton("pre", text: (node.at_css("code") || node).text.chomp)]
      when "code"
        [skeleton("code", text: node.text)]
      when "a"
        next [] if anchor?(node)

        href = node["data-orig-href"] || node["href"]
        [skeleton("a", children: actual_skeleton(node.children), href: href && decode(href))]
      when "img"
        [skeleton("img", href: decode(node["data-orig-src"] || node["src"]))]
      when "div"
        # Discourse puts a div around a table and a block spoiler; the AST
        # has no node for either.
        next actual_skeleton(node.children) if TRANSPARENT_DIVS.intersect?(classes(node))

        [skeleton("div", children: actual_skeleton(node.children))]
      when *STRUCTURAL_ELEMENTS
        [skeleton(node.name, children: actual_skeleton(node.children))]
      else
        actual_skeleton(node.children)
      end
    end
  end

  # markdown-it percent-encodes `]` and `\` in a destination.
  def decode(value)
    URI.decode_uri_component(value.to_s)
  end

  # The classes Discourse gives a div the AST has no node for: around a
  # table, a block spoiler, and the title line of an attributed quote.
  TRANSPARENT_DIVS = Set["md-table", "spoiler", "title", "quote-controls"].freeze

  def classes(node)
    node["class"].to_s.split
  end

  # The anchor link Discourse puts into a heading.
  def anchor?(node)
    node.name == "a" && classes(node).include?("anchor")
  end

  def format_skeleton(nodes, level: 0)
    nodes
      .map do |node|
        line = "#{"  " * level}#{node[:name]}"
        line << " href=#{node[:href].inspect}" if node[:href]
        line << " #{node[:text].inspect}" if node[:text]
        [line, *(format_skeleton(node[:children], level: level + 1) unless node[:children].empty?)]
      end
      .flatten
      .join("\n")
      .then { |text| text.empty? ? "(nothing)" : text }
  end

  # The text a reader sees, with a separator around every block so that
  # words from two blocks never run into each other. +in_link+ says
  # whether a link is among the ancestors: the underline is plain text
  # there. +html+ says whether the node is written in html_mode: no
  # BBCode there, a details block is a <details> with a <summary>, and
  # a file upload is a link with the file name.
  def expected_text(node, out, in_link: false, html: false)
    case node
    when AST::MarkdownText
      # A paragraph of its own in html_mode, see #expected_skeleton.
      html ? separated(out) { out << node.text } : out << node.text
    when AST::Text
      out << node.text
    when AST::Image
      # Discourse reads the image options off the alt text and trims it,
      # Unicode spaces included.
      alt = node.alt.to_s
      alt = alt.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "") if @cooker.cooks?(:image_options)
      out << alt
    when AST::Mention
      out << "@#{node.name}"
    when AST::Upload
      # In html_mode the upload is a Markdown island, a paragraph of its
      # own. A file attachment inside a link label is its name, text in
      # both modes.
      if in_link && node.type == :attachment && node.raw.nil?
        out << (node.filename || "attachment")
        out << " (#{node.size})" if node.size
      elsif html
        separated(out) { expected_upload_text(node, out) }
      else
        expected_upload_text(node, out)
      end
    when AST::Url, AST::Email
      # A link without visible text shows its href.
      if node.children.any? { |child| visible?(child) }
        expected_children_text(node, out, in_link: true, html:)
      elsif node.is_a?(AST::Url)
        out << node.href.to_s
      elsif node.address
        out << "mailto:#{node.address}"
      end
    when AST::Underline
      plain = in_link || html || !visible?(node) || @cooker.cooks?(:underline)
      underline_text(node, out, in_link:, html:, plain:)
    when AST::Color, AST::Size
      # The BBCode of discourse-bbcode is text to a cooker without the
      # plugin; in html_mode and in a link the tag writes no BBCode.
      value = node.is_a?(AST::Color) ? node.color : node.size
      open = node.is_a?(AST::Color) ? "[color=#{value}]" : "[size=#{value}]"
      close = node.is_a?(AST::Color) ? "[/color]" : "[/size]"
      plain = !@features[:bbcode] || html || in_link || !visible?(node) || @cooker.cooks?(:bbcode)
      bbcode_text(node, out, in_link:, html:, open:, close:, plain:)
    when AST::Spoiler
      out << "#{node.title.strip}: " if node.title.to_s.match?(/[^[:space:]]/) && visible?(node)
      plain = html || in_link || !visible?(node) || !@features[:spoiler] || @cooker.cooks?(:spoiler)
      bbcode_text(node, out, in_link:, html:, open: "[spoiler]", close: "[/spoiler]", plain:)
    when AST::Details
      if !@features[:details]
        separated(out) do
          title = details_title(node)
          separated(out) { out << title } if title && visible?(node)
          expected_children_text(node, out, in_link:, html:)
        end
      elsif html
        summary_text(node.title || "Summary", node, out, in_link:) if visible?(node)
      elsif @cooker.cooks?(:details)
        # The summary of the cooked block is the title, nothing without one.
        summary_text(node.title.to_s, node, out, in_link:, html: false) if visible?(node)
      else
        separated(out) do
          bbcode_text(
            node,
            out,
            in_link:,
            html:,
            open: "#{details_opener(node)}\n",
            close: "\n[/details]",
            plain: !visible?(node),
          )
        end
      end
    when AST::Quote
      if html || !bbcode_quote?(node)
        separated(out) { expected_children_text(node, out, in_link:, html:) }
      elsif @cooker.cooks?(:quote)
        # The engine puts the name in a title line above the quote.
        separated(out) do
          name = quote_name(node)
          separated(out) { out << "#{name}:" } if name
          expected_children_text(node, out, in_link:, html:)
        end
      else
        separated(out) do
          bbcode_text(
            node,
            out,
            in_link:,
            html:,
            open: "#{quote_opener(node)}\n",
            close: "\n[/quote]",
            plain: !visible?(node),
          )
        end
      end
    when AST::Code
      if block_code?(node)
        separated(out) { expected_children_text(node, out, in_link:, html:) }
      else
        expected_children_text(node, out, in_link:, html:)
      end
    when AST::Table
      separated(out) { expected_children_text(node, out, in_link:, html: html_table?(node)) }
    when *BLOCK_NODES
      separated(out) do
        expected_children_text(node, out, in_link:, html:) if node.is_a?(AST::Element)
      end
    when AST::Element
      expected_children_text(node, out, in_link:, html:)
    end
    out
  end

  def expected_children_text(element, out, in_link: false, html: false)
    element.children.each { |child| expected_text(child, out, in_link:, html:) }
  end

  # BBCode around the content, or the content alone when +plain+.
  def bbcode_text(node, out, in_link:, html:, open:, close:, plain:)
    out << open unless plain
    expected_children_text(node, out, in_link:, html:)
    out << close unless plain
  end

  # The serializer moves a line break at the start of an underline out
  # of the tag, with the whitespace at both edges, so `[u]` as text
  # stands after it.
  def underline_text(node, out, in_link:, html:, plain:)
    inner = +""
    expected_children_text(node, inner, in_link:, html:)
    return out << inner if plain
    return out << "[u]" << inner << "[/u]" unless inner.match?(/\A[[:blank:]]*\n/)

    lead, core, trail = inner.match(/\A([[:space:]]*)(.*?)([[:space:]]*)\z/m).captures
    out << lead << "[u]" << core << "[/u]" << trail
  end

  # @return [String, nil] the title of a details block, nil when it is
  #   empty or whitespace
  def details_title(node)
    title = node.title.to_s.strip
    title.empty? ? nil : title
  end

  # The opening tag DetailsTag writes.
  def details_opener(node)
    node.title ? %([details="#{node.title}"]) : "[details]"
  end

  # Whether QuoteTag writes the quote as BBCode: attributed, or around an
  # attributed quote (Discourse cooks no `[quote="…"]` inside a Markdown
  # blockquote).
  def bbcode_quote?(node)
    return true if quote_name(node)

    node.descendants(AST::Quote).any? { |inner| quote_name(inner) }
  end

  # @return [String, nil] the name QuoteTag writes into the opening tag
  def quote_name(node)
    return node.username if node.username && node.post_number && node.topic_id

    node.author || node.username
  end

  # The opening tag QuoteTag writes.
  def quote_opener(node)
    if node.username && node.post_number && node.topic_id
      %([quote="#{node.username}, post:#{node.post_number}, topic:#{node.topic_id}"])
    elsif quote_name(node)
      %([quote="#{quote_name(node)}"])
    else
      "[quote]"
    end
  end

  # A <details> element: the summary on a line of its own, then the
  # content, as blocks.
  def summary_text(title, node, out, in_link:, html: true)
    separated(out) do
      separated(out) { out << title }
      expected_children_text(node, out, in_link:, html:)
    end
  end

  # An image shows its alt text, a file link its name and size. Discourse
  # reads the dimensions and the attachment marker off the text and trims
  # the alt text (see expected_text for AST::Image), plain markdown-it
  # shows both.
  def expected_upload_text(node, out)
    if node.type == :image
      alt = node.alt.to_s
      if @cooker.cooks?(:image_options)
        alt = alt.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
      elsif node.dimensions
        alt = "#{alt}|#{node.dimensions}"
      end
      out << alt
    else
      out << (node.filename || "attachment")
      out << "|attachment" unless @cooker.cooks?(:attachment)
      out << " (#{node.size})" if node.size
    end
  end

  def separated(out)
    out << "\n"
    yield
    out << "\n"
  end

  def cooked_text(node, out)
    node.children.each do |child|
      if child.text?
        out << child.text
      elsif child.element?
        case child.name
        when "img"
          out << child["alt"].to_s
        when *BLOCK_ELEMENTS
          separated(out) { cooked_text(child, out) }
        else
          cooked_text(child, out)
        end
      end
    end
    out
  end

  # Whitespace runs are one space, a no-break space among them: the
  # escaper writes indentation as no-break spaces. Curly quotes are
  # straight ones, the typographer is display.
  def normalize_text(text)
    text
      .gsub(/[[:space:]]+/, " ")
      .strip
      .tr(MarkdownItCooker::CURLY_QUOTES, MarkdownItCooker::STRAIGHT_QUOTES)
  end

  # The destinations below +element+, in document order. +in_link+ says
  # whether a link is among the ancestors: a file attachment is its name
  # there, with no destination of its own.
  def expected_links(element, in_link: false)
    element.children.flat_map do |node|
      own =
        case node
        when AST::Url
          node.href if linkable?(node.href)
        when AST::Email
          "mailto:#{node.address}" if node.address
        when AST::Image
          node.src if node.src
        when AST::Upload
          upload_destination(node) unless in_link && node.type == :attachment && node.raw.nil?
        end
      nested =
        if node.is_a?(AST::Element)
          expected_links(node, in_link: in_link || node.is_a?(AST::Url) || node.is_a?(AST::Email))
        else
          []
        end
      [own, *nested].compact
    end
  end

  # Whether an item of +list+ holds something the renderer writes with
  # blank lines around it. Such a list is loose on purpose and the lists
  # check leaves it alone.
  def may_be_loose?(list)
    list.children.any? do |item|
      item.is_a?(AST::Element) &&
        item.children.any? do |child|
          BLANK_LINE_NODES.any? { |klass| child.is_a?(klass) } ||
            (child.is_a?(AST::Code) && block_code?(child)) || blank_line_in?(child)
        end
    end
  end

  # A text with a blank line in it is a paragraph break the source wrote.
  def blank_line_in?(node)
    (node.is_a?(AST::Text) || node.is_a?(AST::MarkdownText)) && node.text.match?(/\n[ \t]*\n/)
  end
end
