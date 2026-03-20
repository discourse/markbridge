# frozen_string_literal: true

require "json"
require "commonmarker"

# Validates the MarkdownEscaper against all CommonMark Spec 0.31.2 examples.
#
# Two properties are checked for every example:
#
# 1. **Structure** — block-level constructs (headings, code blocks, lists, …)
#    must be neutralized to plain paragraph text; inline/paragraph examples
#    must stay paragraph-level; autolinks must be preserved or degrade to
#    paragraph text.
#
# 2. **Content preservation** — every word that appears in the spec's expected
#    HTML output must still appear after escaping and re-rendering. This catches
#    bugs where the escaper silently drops or corrupts text.
RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  context "with CommonMark Spec 0.31.2 examples" do
    let(:escaper) { described_class.new(escape_hard_line_breaks: true) }

    SPEC_EXAMPLES = JSON.parse(SPEC_ROOT.join("fixtures/commonmark_spec_0.31.2.json").read)

    # Block-level tags that indicate the escaper failed to neutralize a construct
    BLOCK_TAG = %r{<(?:h[1-6]|pre|blockquote|[uo]l|li|hr|table|div)[\s/>]}

    COMMONMARK_OPTIONS = { render: { escaped_char_spans: false }, extension: {} }.freeze

    def render_commonmark(text)
      Commonmarker.to_html(text.encode("UTF-8"), options: COMMONMARK_OPTIONS)
    end

    def paragraph_only?(html)
      !BLOCK_TAG.match?(html)
    end

    # Extract meaningful words from rendered HTML for content preservation checks.
    # Strips tags then collects alphanumeric runs. Uses [[:alnum:]] rather than
    # \w to avoid underscore, which is a markdown formatting character.
    def content_words(html)
      html.gsub(/<[^>]*>/, " ").scan(/[[:alnum:]]+/u)
    end

    # Verify that every word from the original markdown survives escaping.
    # Compares against the input markdown (not the spec HTML) because the
    # escaper intentionally prevents entity decoding and HTML interpretation.
    def expect_content_preserved(input:, escaped:)
      missing = content_words(input) - content_words(escaped)

      expect(missing).to(
        be_empty,
        "Lost text content: #{missing.inspect}\nInput: #{input.inspect}\nEscaped: #{escaped.inspect}",
      )
    end

    # Truncated preview of markdown input for test descriptions
    def self.preview(markdown)
      text = markdown.tr("\n", "\u23CE")
      text.length > 50 ? "#{text[0, 47]}..." : text
    end

    # Autolink examples: the spec's Autolinks section plus examples from other
    # sections that contain autolinks embedded in other constructs
    AUTOLINK_EXAMPLE_IDS =
      SPEC_EXAMPLES
        .select do |ex|
          ex["section"] == "Autolinks" || ex["markdown"].include?("<https://") ||
            ex["markdown"].include?("<http://") || ex["markdown"].include?("<mailto:")
        end
        .map { |ex| ex["example"] }
        .to_set
        .freeze

    NON_AUTOLINK_EXAMPLES =
      SPEC_EXAMPLES.reject { |ex| AUTOLINK_EXAMPLE_IDS.include?(ex["example"]) }

    MARKUP_EXAMPLES, PLAIN_EXAMPLES =
      NON_AUTOLINK_EXAMPLES.partition { |ex| BLOCK_TAG.match?(ex["html"]) }

    AUTOLINK_EXAMPLES = SPEC_EXAMPLES.select { |ex| AUTOLINK_EXAMPLE_IDS.include?(ex["example"]) }

    describe "block-level constructs" do
      MARKUP_EXAMPLES.each do |ex|
        it "renders #{preview(ex["markdown"])} as plain text (#{ex["section"]}, example #{ex["example"]})" do
          escaped = escaper.escape(ex["markdown"])
          result_html = render_commonmark(escaped)

          expect(result_html).to(
            satisfy("contain no block-level HTML tags") { |html| paragraph_only?(html) },
            "Input: #{ex["markdown"].inspect}\nEscaped: #{escaped.inspect}\nGot: #{result_html.inspect}",
          )

          expect_content_preserved(input: ex["markdown"], escaped:)
        end
      end
    end

    describe "inline content" do
      PLAIN_EXAMPLES.each do |ex|
        it "preserves #{preview(ex["markdown"])} as paragraph (#{ex["section"]}, example #{ex["example"]})" do
          escaped = escaper.escape(ex["markdown"])
          result_html = render_commonmark(escaped)

          expect(result_html).to(
            satisfy("contain no block-level HTML tags") { |html| paragraph_only?(html) },
            "Input: #{ex["markdown"].inspect}\nEscaped: #{escaped.inspect}\nGot: #{result_html.inspect}",
          )

          expect_content_preserved(input: ex["markdown"], escaped:)
        end
      end
    end

    describe "autolinks" do
      AUTOLINK_EXAMPLES.each do |ex|
        it "preserves #{preview(ex["markdown"])} (#{ex["section"]}, example #{ex["example"]})" do
          escaped = escaper.escape(ex["markdown"])
          result_html = render_commonmark(escaped)

          expect(result_html).to(
            satisfy("preserve autolinks or render as paragraph") do |html|
              html.include?("<a ") || paragraph_only?(html)
            end,
            "Input: #{ex["markdown"].inspect}\nEscaped: #{escaped.inspect}\nGot: #{result_html.inspect}",
          )

          expect_content_preserved(input: ex["markdown"], escaped:)
        end
      end
    end
  end
end
