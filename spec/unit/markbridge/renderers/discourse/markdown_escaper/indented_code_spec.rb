# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "indented code blocks" do
    # NBSP (non-breaking space) is used to preserve visual indentation
    # without triggering code blocks or block-level markdown
    let(:nbsp) { "\u00A0" }

    context "when 4+ spaces at line start (MUST escape to prevent code block)" do
      it "converts 4-space indent to NBSP" do
        input = "    code line"
        result = escaper.escape(input)
        expect(result).to eq("#{nbsp * 4}code line")
        expect(result).not_to match(/\A {4}/) # No regular spaces at start
      end

      it "converts 5-space indent to NBSP" do
        input = "     code line"
        result = escaper.escape(input)
        expect(result).to eq("#{nbsp * 5}code line")
      end

      it "converts 8-space indent to NBSP" do
        input = "        deeply indented"
        result = escaper.escape(input)
        expect(result).to eq("#{nbsp * 8}deeply indented")
      end

      it "converts tab indent to 4 NBSP" do
        input = "\tcode line"
        result = escaper.escape(input)
        expect(result).to eq("#{nbsp * 4}code line")
      end

      it "escapes multiline indented code block" do
        input = "    // comment\n    line 1\n    line 2"
        result = escaper.escape(input)
        # Each line should have NBSP instead of spaces
        result.lines.each do |line|
          expect(line).not_to match(/\A {4}/),
          "Line should not start with 4 spaces: #{line.inspect}"
          expect(line).to start_with(nbsp)
        end
      end

      it "escapes indented code following paragraph" do
        input = "Paragraph\n\n    // comment\n    code"
        result = escaper.escape(input)
        expect(result).to include("Paragraph")
        expect(result).to include("#{nbsp * 4}// comment")
        expect(result).not_to match(/\n {4}/)
      end

      it "escapes inline content and converts indent" do
        input = "    *asterisk* and `backtick`"
        result = escaper.escape(input)
        # NBSP indent + escaped inline content
        expect(result).to eq("#{nbsp * 4}\\*asterisk\\* and \\`backtick\\`")
      end

      it "prevents block-level interpretation of indented content" do
        # These would be block elements at 0-3 space indent, but NBSP prevents that
        expect(escaper.escape("    - list item")).to eq("#{nbsp * 4}- list item")
        expect(escaper.escape("    # heading")).to eq("#{nbsp * 4}# heading")
        expect(escaper.escape("    > quote")).to eq("#{nbsp * 4}> quote")
        expect(escaper.escape("    1. ordered")).to eq("#{nbsp * 4}1. ordered")
      end

      # Space + tab combinations that reach column 4+
      it "converts 2 spaces + tab to NBSP (reaches column 4)" do
        input = "  \tfoo"
        result = escaper.escape(input)
        # 2 spaces + tab (4 columns) = 6 NBSP total (2 for spaces, 4 for tab)
        expect(result).to start_with(nbsp)
        expect(result).not_to match(/\A[ \t]/)
      end

      it "converts 1 space + tab to NBSP" do
        input = " \tfoo"
        result = escaper.escape(input)
        expect(result).to start_with(nbsp)
        expect(result).not_to match(/\A[ \t]/)
      end

      it "converts 3 spaces + tab to NBSP" do
        input = "   \tfoo"
        result = escaper.escape(input)
        expect(result).to start_with(nbsp)
        expect(result).not_to match(/\A[ \t]/)
      end
    end

    context "when less than 4 spaces indent (not code blocks)" do
      it "preserves 3-space indent without modification" do
        input = "   three spaces"
        result = escaper.escape(input)
        expect(result).to eq(input)
      end

      it "preserves 2-space indent without modification" do
        input = "  two spaces"
        result = escaper.escape(input)
        expect(result).to eq(input)
      end

      it "preserves 1-space indent without modification" do
        input = " one space"
        result = escaper.escape(input)
        expect(result).to eq(input)
      end
    end

    context "when indentation is mixed in document" do
      it "converts only the 4+ space lines to NBSP" do
        input = "Normal paragraph.\n\n    Code line 1\n    Code line 2\n\nBack to normal."
        result = escaper.escape(input)
        expect(result).to include("Normal paragraph.")
        expect(result).to include("Back to normal.")
        expect(result).to include("#{nbsp * 4}Code line 1")
        expect(result).to include("#{nbsp * 4}Code line 2")
        expect(result).not_to match(/ {4}Code/)
      end

      it "handles transition from list to indented content" do
        input = "- list item\n\n        indented under list"
        result = escaper.escape(input)
        expect(result).to include("\\-")
        # 8 spaces converted to NBSP
        expect(result).to include("#{nbsp * 8}indented under list")
      end
    end

    # CRLF input (e.g. SharePoint HTML exports) used to leak past the
    # `ws_end >= line_length` early-out in escape_indented_code because
    # `\r` was counted as content, not whitespace. The leading spaces were
    # then converted to NBSPs, producing whitespace-only lines that
    # cleanup_markdown couldn't strip.
    context "with CRLF line endings" do
      it "treats a CRLF whitespace-only indented line as whitespace" do
        result = escaper.escape("    \r\n")
        expect(result).not_to include(nbsp)
      end

      it "does not produce NBSP for a wall of CRLF whitespace-only lines" do
        input = "    \r\n    \r\n    \r\nhello"
        result = escaper.escape(input)
        expect(result).not_to include(nbsp)
        expect(result).to include("hello")
      end

      it "still converts genuine CRLF-terminated indented code to NBSP" do
        input = "    code line\r\n    next line"
        result = escaper.escape(input)
        expect(result).to include("#{nbsp * 4}code line")
        expect(result).to include("#{nbsp * 4}next line")
        expect(result).not_to match(/\A {4}/)
      end
    end
  end
end
