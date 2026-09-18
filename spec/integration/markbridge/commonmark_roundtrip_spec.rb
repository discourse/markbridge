# frozen_string_literal: true

require "json"

# commonmarker's Rust/Magnus native extension only builds on MRI.
require "commonmarker" if RUBY_ENGINE == "ruby"

# Round-trips the CommonMark Spec 0.31.2 examples through the HTML parser
# and the Discourse renderer.
#
# The examples are Markdown -> HTML pairs and the renderer starts from an
# AST, so this spec runs them backwards: it takes the HTML a CommonMark
# parser produces, converts it to Markdown with Markbridge, cooks that
# Markdown with commonmarker and compares the result with the HTML it
# started from. Same HTML in, same HTML out.
#
# Asserting on the Markdown string instead would not find much: a wrong
# indentation or a missing blank line still looks plausible in the string
# and only shows up once a CommonMark parser reads it back.
#
# An example that does not round-trip is either an intended difference or
# a known defect, and both lists say why. The spec also checks that a
# listed example really does not round-trip, so a fixed defect or a
# changed decision forces the list to be updated.
module CommonMarkRoundTrip
  EXAMPLES = JSON.parse(SPEC_ROOT.join("fixtures/commonmark_spec_0.31.2.json").read).freeze

  # Elements the HTML parser has a handler for (see
  # Markbridge::Parsers::HTML::HandlerRegistry.default). An example whose
  # expected HTML uses anything else is not about markup Markbridge can
  # carry, so it is skipped.
  SUPPORTED_ELEMENTS = %w[
    a
    b
    blockquote
    br
    code
    del
    em
    h1
    h2
    h3
    h4
    h5
    h6
    hr
    i
    img
    li
    ol
    p
    pre
    s
    span
    strong
    sub
    sup
    table
    tbody
    td
    th
    thead
    tr
    u
    ul
  ].to_set.freeze

  # Both sections are about HTML that CommonMark passes through unchanged.
  # Markbridge parses that HTML instead of passing it through, so there is
  # nothing to round-trip.
  SKIPPED_SECTIONS = ["HTML blocks", "Raw HTML"].freeze

  # Elements that start a new block. Whitespace next to one is layout, not
  # content (see #normalize).
  BLOCK_ELEMENTS = %w[
    blockquote
    div
    h1
    h2
    h3
    h4
    h5
    h6
    hr
    li
    ol
    p
    pre
    table
    tbody
    td
    th
    thead
    tr
    ul
  ].to_set.freeze

  # * unsafe: the spec's HTML keeps every link and image destination,
  #   commonmarker would otherwise drop some of them.
  # * escaped_char_spans: off, we do not want a <span> around every
  #   backslash escape the renderer writes.
  # * github_pre_lang: off, so a fenced code block cooks to the
  #   <pre><code class="language-x"> shape the spec expects.
  # * header_ids: off, the spec's headings carry no anchor.
  # * strikethrough: on, the renderer writes ~~ for <del> and <s>.
  #
  # The autolink extension stays on (it is a commonmarker default, and
  # Discourse links bare URLs too). That is what makes the renderer's
  # bare-URL form round-trip at all, and the few examples where the spec
  # keeps a URL as plain text are listed as intended differences.
  COMMONMARK_OPTIONS = {
    render: {
      unsafe: true,
      escaped_char_spans: false,
      github_pre_lang: false,
    },
    extension: {
      header_ids: nil,
      strikethrough: true,
    },
  }.freeze

  # The syntax highlighter would wrap every code block in <span> markup.
  COMMONMARK_PLUGINS = { syntax_highlighter: nil }.freeze

  # Reasons, so that the id lists below stay readable.
  EMPTY_ELEMENT = "an element without content renders to nothing"
  LINK_WITHOUT_TEXT =
    "a link without text renders as its bare href, and a link with an empty href " \
      "is dropped and keeps only its text"
  BARE_URL =
    "a link whose text is its href renders as the bare URL (it oneboxes in Discourse), " \
      "and the cooking engine links only http(s) and mail addresses back"
  COOKED_AUTOLINK =
    "the cooking engine links a bare URL or mail address that the spec keeps as plain text"
  BOLD_IS_STRONG = "<b> and <strong> share one AST node, the renderer always writes **"
  ASCII_LANGUAGE_ONLY = "the HTML parser takes only an ASCII token as the language of a code block"

  LINK_DESTINATION_PARENTHESES =
    "an unbalanced parenthesis in a link destination is neither escaped nor wrapped in <>"
  BANG_BEFORE_LINK = "a ! in front of a link is not escaped, so the link cooks as an image"
  MERGED_LISTS = "two adjacent lists of the same kind merge into one loose list"
  RULE_IN_LIST_ITEM =
    "a horizontal rule inside a list item is written as ---, which cooks as a thematic " \
      "break and ends the list"
  HEADING_TRAILING_HASHES =
    "a # at the end of a heading is not escaped and is eaten as the closing sequence"
  BARE_URL_AFTER_WORD =
    "a link whose text is its href renders as the bare URL, which is not linked again " \
      "when a word sits directly in front of it"

  # Turn {reason => [ids]} into {id => reason}.
  def self.by_example(groups)
    groups.each_with_object({}) { |(reason, ids), map| ids.each { |id| map[id] = reason } }.freeze
  end

  # Examples where Markbridge deliberately renders something else.
  INTENDED_DIFFERENCES =
    by_example(
      EMPTY_ELEMENT => [126, 130, 144, 218, 237, 239, 240, 280, 281, 282, 283, 284, 315],
      LINK_WITHOUT_TEXT => [21, 31, 200, 476, 477, 484, 485, 486, 487, 567, 642, 643],
      BARE_URL => [344, 596, 597, 598, 599, 601],
      COOKED_AUTOLINK => [602, 606, 608, 611, 612],
      BOLD_IS_STRONG => [494],
      ASCII_LANGUAGE_ONLY => [34],
    )

  # Examples that fail because of a defect. Fixing one must remove its entry.
  KNOWN_BUGS =
    by_example(
      LINK_DESTINATION_PARENTHESES => [492, 498, 499, 500],
      BANG_BEFORE_LINK => [593],
      MERGED_LISTS => [301, 302, 308],
      RULE_IN_LIST_ITEM => [61],
      HEADING_TRAILING_HASHES => [76],
      BARE_URL_AFTER_WORD => [480, 481],
    )

  module_function

  # The examples this spec runs: everything outside the two skipped
  # sections whose expected HTML is markup the HTML parser knows.
  def round_trippable_examples
    @round_trippable_examples ||=
      EXAMPLES.reject do |example|
        SKIPPED_SECTIONS.include?(example["section"]) || example["html"].strip.empty? ||
          !supported?(example["html"])
      end
  end

  # Uses Nokogiri::HTML, the parser Markbridge's own HTML parser uses. It
  # also runs on JRuby, where this spec is skipped but the example list is
  # still built (Nokogiri::HTML5 is MRI only).
  def supported?(html)
    Nokogiri::HTML.fragment(html).css("*").all? { |node| SUPPORTED_ELEMENTS.include?(node.name) }
  end

  def cook(markdown)
    Commonmarker.to_html(markdown, options: COMMONMARK_OPTIONS, plugins: COMMONMARK_PLUGINS)
  end

  # Brings both sides into a shape where only differences Markbridge is
  # responsible for are left. Every rule here is a difference that shows
  # up in many examples and that Markbridge cannot carry, not a single
  # example that would not pass otherwise.
  def normalize(html)
    fragment = Nokogiri::HTML5.fragment(html)

    # A comment renders to nothing. The HTML parser drops the ones in the
    # input, and the renderer writes an empty <!----> of its own to keep
    # two Markdown constructs apart.
    fragment.xpath(".//comment()").each(&:remove)

    # A CommonMark parser wraps the content of a list item in <p> when the
    # list is loose. The AST does not carry that difference: the renderer
    # decides tight or loose from what is inside the item. Everything else
    # about the list (nesting, order, indentation) still has to match.
    fragment.css("li > p").each { |paragraph| paragraph.replace(paragraph.children) }

    normalize_whitespace(fragment)

    # Attributes Markbridge does not carry: the title of a link or an
    # image, and the start number of an ordered list.
    fragment.css("a[title], img[title]").each { |node| node.remove_attribute("title") }
    fragment.css("ol[start]").each { |node| node.remove_attribute("start") }

    # commonmarker always writes the alt attribute, the spec leaves it out
    # when it is empty. An alt text that got lost still shows up, because
    # then only one of the two sides is empty.
    fragment.css("img[alt='']").each { |node| node.remove_attribute("alt") }

    fragment.to_html
  end

  # Inside <pre> every space counts. Outside, a run of whitespace is one
  # space, and whitespace next to a block boundary is layout the Markdown
  # writer is free to place differently. Whitespace between two inline
  # elements is kept, so a lost space between two words or two links is
  # still a difference.
  def normalize_whitespace(fragment)
    fragment.traverse do |node|
      next unless node.text?
      next if node.ancestors.any? { |ancestor| ancestor.name == "pre" }

      text = node.text.gsub(/\s+/, " ")
      text = text.lstrip if block_boundary?(node.previous_sibling, node.parent)
      text = text.rstrip if block_boundary?(node.next_sibling, node.parent)
      text.empty? ? node.remove : node.content = text
    end
  end

  # A text node touches a block boundary when the neighbour on that side
  # is a block element, or when there is no neighbour and the node sits
  # at the edge of a block element.
  def block_boundary?(sibling, parent)
    node = sibling || parent
    node.element? && BLOCK_ELEMENTS.include?(node.name)
  end

  # Truncated preview of the input for the test description.
  def preview(html)
    text = html.strip.tr("\n", "⏎")
    text.length > 50 ? "#{text[0, 47]}..." : text
  end
end

skip_reason = "commonmarker not available on #{RUBY_ENGINE}" unless RUBY_ENGINE == "ruby"

RSpec.describe "CommonMark spec round-trip", skip: skip_reason do
  # Converts one example and returns what to compare, plus the message
  # that tells the whole story when the comparison is not what the list
  # above says it should be.
  def round_trip(example)
    markdown = Markbridge.html_to_markdown(example["html"]).markdown
    cooked = CommonMarkRoundTrip.cook(markdown)
    message =
      "Example #{example["example"]} (#{example["section"]})\n" \
        "HTML in:  #{example["html"].inspect}\n" \
        "Markdown: #{markdown.inspect}\n" \
        "HTML out: #{cooked.inspect}"

    [CommonMarkRoundTrip.normalize(cooked), CommonMarkRoundTrip.normalize(example["html"]), message]
  end

  it "lists no example as both an intended difference and a known bug" do
    overlap = CommonMarkRoundTrip::INTENDED_DIFFERENCES.keys & CommonMarkRoundTrip::KNOWN_BUGS.keys

    expect(overlap).to be_empty
  end

  it "lists only examples this spec runs" do
    listed = CommonMarkRoundTrip::INTENDED_DIFFERENCES.keys + CommonMarkRoundTrip::KNOWN_BUGS.keys
    ids = CommonMarkRoundTrip.round_trippable_examples.map { |example| example["example"] }

    expect(listed - ids).to be_empty
  end

  CommonMarkRoundTrip.round_trippable_examples.each do |example|
    id = example["example"]
    reason = CommonMarkRoundTrip::INTENDED_DIFFERENCES[id] || CommonMarkRoundTrip::KNOWN_BUGS[id]
    label = "#{CommonMarkRoundTrip.preview(example["html"])} (#{example["section"]}, example #{id})"

    if reason
      it "does not round-trip #{label}: #{reason}" do
        cooked, expected, message = round_trip(example)

        expect(cooked).not_to eq(expected), message
      end
    else
      it "round-trips #{label}" do
        cooked, expected, message = round_trip(example)

        expect(cooked).to eq(expected), message
      end
    end
  end
end
