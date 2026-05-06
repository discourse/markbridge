# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::IdentityEscaper do
  let(:escaper) { described_class.new }

  describe "#escape" do
    it "returns the input unchanged" do
      expect(escaper.escape("**hi** *star* `code` <tag>")).to eq("**hi** *star* `code` <tag>")
    end

    it "preserves whitespace and newlines verbatim" do
      input = "  leading\n  middle\n  trailing  "
      expect(escaper.escape(input)).to eq(input)
    end

    it "returns the same object when given a String (no allocation)" do
      input = +"plain"
      expect(escaper.escape(input)).to be(input)
    end

    it "returns an empty string for nil (parity with MarkdownEscaper#escape)" do
      expect(escaper.escape(nil)).to eq("")
    end
  end

  describe "as plumbed through Markbridge.discourse_renderer(escape: false)" do
    let(:renderer) { Markbridge.discourse_renderer(escape: false) }

    it "leaves Markdown-special characters in Text nodes untouched" do
      result = renderer.render(Markbridge::AST::Text.new("a*b_c [d](e)"))

      expect(result).to eq("a*b_c [d](e)")
    end

    it "leaves block-level constructs untouched (lists, headings, quotes)" do
      result = renderer.render(Markbridge::AST::Text.new("# Heading\n- item\n1. ordered\n> quoted"))

      expect(result).to eq("# Heading\n- item\n1. ordered\n> quoted")
    end

    it "is end-to-end usable through bbcode_to_markdown" do
      result = Markbridge.bbcode_to_markdown("[b]hi[/b] *raw* `untouched`", renderer:)

      # The Bold tag still wraps; the surrounding text is *not* escaped.
      expect(result.markdown).to eq("**hi** *raw* `untouched`")
    end
  end

  describe "discourse_renderer mutual-exclusion" do
    it "raises when escape: false is combined with escape_hard_line_breaks: true" do
      expect {
        Markbridge.discourse_renderer(escape: false, escape_hard_line_breaks: true)
      }.to raise_error(ArgumentError, /mutually exclusive/)
    end

    it "raises when escape: false is combined with allow:" do
      expect { Markbridge.discourse_renderer(escape: false, allow: :lists) }.to raise_error(
        ArgumentError,
        /mutually exclusive/,
      )
    end

    it "lets an explicit escaper: win even when escape: false is given" do
      explicit = Markbridge::Renderers::Discourse::MarkdownEscaper.new
      renderer = Markbridge.discourse_renderer(escaper: explicit, escape: false)

      # The MarkdownEscaper still escapes, so `*` becomes `\*`.
      result = renderer.render(Markbridge::AST::Text.new("a*b"))
      expect(result).to eq('a\*b')
    end
  end
end
