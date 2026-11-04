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
# A fifth, normalizer, comes first: the AST has to be one the default
# normalizer leaves alone, so the tree that is rendered is the tree the
# expectation reads.
class RoundTripChecker
  AST = Markbridge::AST

  Failure = Data.define(:check, :message)

  CHECKS = %i[normalizer shape structure text links lists].freeze

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
    del
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
  ALWAYS_WRITTEN = [AST::Align, AST::Heading, AST::Superscript, AST::Subscript].freeze

  # Schemes the renderer links (see UrlTag). Anything else that looks like
  # a scheme is dropped, a scheme-less href passes.
  LINKABLE_SCHEME = /\A(?:https?|ftps?|mailto):/i
  SCHEME_LIKE = /\A[a-z][a-z0-9+.-]*:/i

  # markdown-it's typographer turns straight quotes into curly ones.
  CURLY_QUOTES = "\u201C\u201D\u2018\u2019"
  STRAIGHT_QUOTES = "\"\"''"

  # Without the normalizer: {#failures} has checked that it would change
  # nothing, and it drops an emptied element in place, which would take
  # the tree out from under the shrinker's undo.
  #
  # @param document [Markbridge::AST::Document]
  # @return [String]
  def render(document)
    Markbridge.render(document, normalize: false).markdown
  end

  # @param markdown [String]
  # @return [String]
  def cook(markdown)
    MarkdownItCooker.cook(markdown)
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

  def check_links(document, fragment)
    expected = expected_links(document).sort
    actual =
      fragment.css("a[href], img[src]").map { |node| decode(node["href"] || node["src"]) }.sort
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
  # @return [Array<Hash>] the skeleton nodes this AST node stands for.
  #   Document, Paragraph, Text and LineBreak add no node of their own,
  #   their content moves up to the parent. A container with nothing
  #   visible in it renders to nothing and adds no node either.
  def expected_skeleton(node)
    return [] if node.is_a?(AST::Element) && !visible?(node)

    case node
    when AST::List
      [skeleton(node.ordered? ? "ol" : "ul", children: expected_children(node))]
    when AST::ListItem
      [skeleton("li", children: expected_children(node))]
    when AST::Quote
      [skeleton("blockquote", children: expected_children(node))]
    when AST::Code
      [expected_code(node)]
    when AST::Url
      expected_link(node)
    when AST::Email
      if node.address
        [skeleton("a", children: expected_children(node), href: "mailto:#{node.address}")]
      else
        expected_children(node)
      end
    when AST::Image
      [skeleton("img", href: node.src)]
    when AST::Heading
      [skeleton("h#{node.level}", children: expected_children(node))]
    when AST::Align
      [skeleton("div", children: expected_children(node))]
    when AST::Superscript
      [skeleton("sup", children: expected_children(node))]
    when AST::Subscript
      [skeleton("sub", children: expected_children(node))]
    when AST::Table
      [expected_table(node)]
    when AST::Upload
      [expected_upload(node)]
    when AST::Bold
      [skeleton("strong", children: expected_children(node))]
    when AST::Italic
      [skeleton("em", children: expected_children(node))]
    when AST::Strikethrough
      [skeleton("s", children: expected_children(node))]
    when AST::HorizontalRule
      [skeleton("hr")]
    when AST::Element
      expected_children(node)
    else
      []
    end
  end

  def expected_children(element)
    element.children.flat_map { |child| expected_skeleton(child) }
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
    when AST::Table
      node.descendants.any?(AST::TableCell)
    when AST::Element
      node.children.any? { |child| visible?(child) }
    else
      false
    end
  end

  # The renderer takes the first row whose cells are all header cells as
  # the header row, or the first row, and a Markdown table always has
  # one. A row without cells is dropped.
  def expected_table(node)
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
                skeleton(index == header ? "th" : "td", children: expected_children(cell))
              end,
          )
        end,
    )
  end

  # An upload is an image or a link to a file, see UploadTag.
  def expected_upload(node)
    destination = upload_destination(node)
    node.type == :image ? skeleton("img", href: destination) : skeleton("a", href: destination)
  end

  def upload_destination(node)
    "upload://#{node.filename || node.sha1}"
  end

  # A link with an href the renderer refuses keeps only its text.
  def expected_link(node)
    return expected_children(node) unless linkable?(node.href)

    [skeleton("a", children: expected_children(node), href: node.href)]
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
        [skeleton("a", children: actual_skeleton(node.children), href: decode(node["href"]))]
      when "img"
        [skeleton("img", href: decode(node["src"]))]
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
  # there.
  def expected_text(node, out, in_link: false)
    case node
    when AST::Text, AST::MarkdownText
      out << node.text
    when AST::Image
      out << node.alt.to_s
    when AST::Mention
      out << "@#{node.name}"
    when AST::Upload
      expected_upload_text(node, out)
    when AST::Url, AST::Email
      # A link without visible text shows its href.
      if node.children.any? { |child| visible?(child) }
        expected_children_text(node, out, in_link: true)
      elsif node.is_a?(AST::Url)
        out << node.href.to_s
      end
    when AST::Underline
      bbcode_text(node, out, in_link:, open: "[u]", close: "[/u]", plain: in_link)
    when AST::Spoiler
      open = node.title ? "[spoiler=#{node.title}]" : "[spoiler]"
      bbcode_text(node, out, in_link:, open:, close: "[/spoiler]", plain: !visible?(node))
    when AST::Details
      separated(out) do
        bbcode_text(
          node,
          out,
          in_link:,
          open: "[details]\n",
          close: "\n[/details]",
          plain: !visible?(node),
        )
      end
    when AST::Code
      if block_code?(node)
        separated(out) { expected_children_text(node, out, in_link:) }
      else
        expected_children_text(node, out, in_link:)
      end
    when *BLOCK_NODES
      separated(out) { expected_children_text(node, out, in_link:) if node.is_a?(AST::Element) }
    when AST::Element
      expected_children_text(node, out, in_link:)
    end
    out
  end

  def expected_children_text(element, out, in_link: false)
    element.children.each { |child| expected_text(child, out, in_link:) }
  end

  # BBCode around the content, or the content alone when +plain+.
  def bbcode_text(node, out, in_link:, open:, close:, plain:)
    out << open unless plain
    expected_children_text(node, out, in_link:)
    out << close unless plain
  end

  # An image shows its alt text, a file link its name and size.
  def expected_upload_text(node, out)
    if node.type == :image
      out << node.alt.to_s
    else
      out << (node.filename || "attachment") << "|attachment"
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
    text.gsub(/[[:space:]]+/, " ").strip.tr(CURLY_QUOTES, STRAIGHT_QUOTES)
  end

  def expected_links(document)
    document.descendants.filter_map do |node|
      case node
      when AST::Url
        node.href if linkable?(node.href)
      when AST::Email
        "mailto:#{node.address}" if node.address
      when AST::Image
        node.src if node.src
      when AST::Upload
        upload_destination(node)
      end
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
            (child.is_a?(AST::Code) && block_code?(child))
        end
    end
  end
end
