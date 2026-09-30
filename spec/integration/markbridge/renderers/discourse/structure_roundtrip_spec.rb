# frozen_string_literal: true

require "nokogiri"
require "uri"

# Asserts on the Markdown string alone and a wrong indentation stays
# invisible: the string still looks plausible while CommonMark reads a code
# fence as indented code. This spec builds nested ASTs from a seeded
# generator, renders them, cooks the Markdown, and compares the structure of
# the cooked HTML with the structure of the AST. The AST says "a list item
# at depth 3 holds a code block", so the cooked DOM has to show an `li` at
# depth 3 with a `pre` inside, and the code text has to be the code.
RSpec.describe "renderer structure round-trip", skip: CookedOutput::SKIP_REASON do
  # commonmarker merges these over its defaults, so table, autolink and
  # tasklist stay on. strikethrough is named because ~~x~~ has to cook to
  # <del>; header_ids drops the id attribute from headings.
  COOK_OPTIONS = {
    render: {
      unsafe: true,
      escaped_char_spans: false,
    },
    extension: {
      header_ids: nil,
      strikethrough: true,
    },
  }.freeze
  COOK_PLUGINS = { syntax_highlighter: nil }.freeze

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
    h1
    h2
    h3
    h4
    h5
    h6
    hr
    div
    s
  ].freeze

  # The renderer falls back to raw HTML when the content already carries
  # the Markdown marker, and its strikethrough fallback is <s> where
  # CommonMark's ~~ produces <del>. Both mean the same element.
  ELEMENT_ALIASES = { "s" => "del" }.freeze

  # Markdown that must never reach the reader as text. Inside pre and code
  # these are content, so the check runs on the rest of the document.
  LEAKED_MARKDOWN = ["```", "~~~", "**", "](", "<!---->"].freeze

  SEED_COUNT = Integer(ENV.fetch("STRUCTURE_SEEDS", "300"))

  def cook(markdown)
    Commonmarker.to_html(markdown, options: COOK_OPTIONS, plugins: COOK_PLUGINS)
  end

  # One skeleton node. The same shape is built from the AST and from the
  # DOM so the two can be compared with a plain ==.
  def skeleton(name, children: [], text: nil, href: nil)
    { name:, children:, text:, href: }
  end

  # @param node [Markbridge::AST::Node]
  # @return [Array<Hash>] the skeleton nodes this AST node stands for.
  #   Document, Paragraph, Text and LineBreak add no node of their own,
  #   their content moves up to the parent.
  def expected_skeleton(node)
    ast = Markbridge::AST

    case node
    when ast::List
      [skeleton(node.ordered? ? "ol" : "ul", children: expected_children(node))]
    when ast::ListItem
      [skeleton("li", children: expected_children(node))]
    when ast::Quote
      [skeleton("blockquote", children: expected_children(node))]
    when ast::Code
      [expected_code(node)]
    when ast::Url
      [skeleton("a", children: expected_children(node), href: node.href)]
    when ast::Heading
      [skeleton("h#{node.level}", children: expected_children(node))]
    when ast::Align
      [skeleton("div", children: expected_children(node))]
    when ast::Bold
      [skeleton("strong", children: expected_children(node))]
    when ast::Italic
      [skeleton("em", children: expected_children(node))]
    when ast::Strikethrough
      [skeleton("del", children: expected_children(node))]
    when ast::HorizontalRule
      [skeleton("hr")]
    when ast::Element
      expected_children(node)
    else
      []
    end
  end

  def expected_children(element)
    element.children.flat_map { |child| expected_skeleton(child) }
  end

  # A code element prints as a fenced block when its block flag is set or
  # its text spans more than one line; otherwise it stays a code span.
  def expected_code(node)
    text = node.descendants(Markbridge::AST::Text).map(&:text).join
    block = node.block || text.include?("\n")

    # One newline at the end of block code is the one in front of the
    # closing fence, so it does not show up in the cooked code.
    block ? skeleton("pre", text: text.chomp) : skeleton("code", text:)
  end

  # @param nodes [Nokogiri::XML::NodeSet]
  # @return [Array<Hash>]
  def actual_skeleton(nodes)
    nodes.flat_map do |node|
      next [] unless node.element?

      case node.name
      when "pre"
        # commonmarker puts the code in a <code> child and ends it with a
        # newline that the source does not have.
        [skeleton("pre", text: (node.at_css("code") || node).text.chomp)]
      when "code"
        [skeleton("code", text: node.text)]
      when "a"
        # commonmarker percent-encodes `]` and `\` in a destination.
        [
          skeleton(
            "a",
            children: actual_skeleton(node.children),
            href: URI.decode_uri_component(node["href"]),
          ),
        ]
      when *STRUCTURAL_ELEMENTS
        [
          skeleton(
            ELEMENT_ALIASES.fetch(node.name, node.name),
            children: actual_skeleton(node.children),
          ),
        ]
      else
        actual_skeleton(node.children)
      end
    end
  end

  def ast_text(document)
    document.descendants(Markbridge::AST::Text).map(&:text).join("\n")
  end

  # Alphanumeric runs, not \w: an underscore is a Markdown formatting
  # character and may legitimately be escaped away from a word.
  def content_words(text)
    text.scan(/[[:alnum:]]+/u)
  end

  # Every word has to show up in the document text. Substring, not a word
  # of its own: an emphasis marker between two words is gone after
  # cooking, so "entry*alice*" arrives as the single run "entryalice".
  def missing_words(document, fragment)
    text = fragment.text
    content_words(ast_text(document)).reject { |word| text.include?(word) }
  end

  # The document text without the parts where Markdown sigils are content.
  # The text runs are kept apart: dropping the elements between them would
  # glue two "*" from different nodes into a "**" that nobody wrote.
  def text_outside_code(fragment)
    fragment.xpath(".//text()[not(ancestor::pre) and not(ancestor::code)]").map(&:text).join("\n")
  end

  def failure_report(seed:, document:, markdown:, html:)
    <<~REPORT
      seed: #{seed}

      AST:
      #{AstGenerator.dump(document)}

      Markdown:
      #{markdown}

      Cooked:
      #{html}
    REPORT
  end

  (1..SEED_COUNT).each do |seed|
    it "renders seed #{seed} to HTML with the structure of its AST" do
      document = AstGenerator.new(seed).document

      # The generator promises trees the default normalizer leaves alone,
      # so the AST that gets rendered is the AST the expectation reads.
      violations = Markbridge::Normalizer.shared_default.violations(document)

      markdown = Markbridge.render(document).markdown
      html = cook(markdown)
      fragment = Nokogiri::HTML5.fragment(html)
      report = failure_report(seed:, document:, markdown:, html:)

      expect(violations).to eq([]), report

      expect(actual_skeleton(fragment.children)).to eq(expected_skeleton(document)), report

      missing = missing_words(document, fragment)
      expect(missing).to eq([]), "lost text: #{missing.inspect}\n\n#{report}"

      outside = text_outside_code(fragment)
      # A marker that a Text node already carries is content, not a leak.
      leaked = LEAKED_MARKDOWN.select { |m| outside.include?(m) && !ast_text(document).include?(m) }
      expect(leaked).to eq([]), "leaked markdown: #{leaked.inspect}\n\n#{report}"
    end
  end
end
