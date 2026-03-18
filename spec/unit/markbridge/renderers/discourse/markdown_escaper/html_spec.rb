# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "autolinks and HTML with < and >" do
    # Autolinks are intentionally NOT escaped (they render as links, which is acceptable)
    # HTML tags MUST be escaped to prevent raw HTML injection

    context "when autolinks are intentionally NOT escaped" do
      it "does not escape URL autolink" do
        result = escaper.escape("<https://example.com>")
        expect(result).to eq("<https://example.com>")
      end

      it "does not escape email autolink" do
        result = escaper.escape("<foo@bar.com>")
        expect(result).to eq("<foo@bar.com>")
      end

      it "does not escape other scheme autolinks" do
        result = escaper.escape("<mailto:test@example.com>")
        expect(result).to eq("<mailto:test@example.com>")
      end
    end

    context "when HTML tags MUST be escaped" do
      it "escapes opening HTML tag" do
        result = escaper.escape("<div>")
        expect(result).to eq("\\<div>")
      end

      it "escapes self-closing HTML tag" do
        result = escaper.escape("<br />")
        expect(result).to eq("\\<br />")
      end

      it "escapes closing HTML tag" do
        result = escaper.escape("</div>")
        expect(result).to eq("\\</div>")
      end

      it "escapes HTML tag with attributes" do
        result = escaper.escape('<a href="url">')
        expect(result).to eq('\\<a href="url">')
      end

      it "escapes img tag" do
        result = escaper.escape('<img src="img.png">')
        expect(result).to eq('\\<img src="img.png">')
      end
    end

    context "when < and > appear in other contexts" do
      it "does not escape < in comparison" do
        result = escaper.escape("5 < 10")
        expect(result).to eq("5 < 10")
      end

      it "escapes > at line start (blockquote)" do
        result = escaper.escape("> quoted")
        expect(result).to eq("\\> quoted")
      end

      it "does not escape > in middle of line" do
        result = escaper.escape("5 > 3")
        expect(result).to eq("5 > 3")
      end

      it "escapes potential HTML at line start for safety" do
        # <tagname at start of line could be multi-line HTML block, so escape it
        result = escaper.escape("<incomplete")
        expect(result).to eq("\\<incomplete")
      end
    end
  end
end
