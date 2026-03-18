# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "#escape" do
    # Helper to verify escaped output renders as literal text
    # The escaper MAY over-escape (false positives allowed), but MUST escape
    # anything that would otherwise be interpreted as Markdown (no false negatives)

    # =========================================================================
    # Characters That Rarely Need Escaping
    # (All MAY escape - false positives OK)
    # =========================================================================

    describe "characters rarely needing escaping in CommonMark" do
      it "may or may not escape $" do
        result = escaper.escape("$100")
        expect(result).to eq("$100").or include("\\$")
      end

      it "may or may not escape %" do
        result = escaper.escape("100%")
        expect(result).to eq("100%").or include("\\%")
      end

      it "may or may not escape ^" do
        result = escaper.escape("x^2")
        expect(result).to eq("x^2").or include("\\^")
      end

      it "may or may not escape { }" do
        result = escaper.escape("{foo}")
        expect(result).to eq("{foo}").or include("\\{")
      end

      it "may or may not escape |" do
        result = escaper.escape("a | b")
        expect(result).to eq("a | b").or include("\\|")
      end

      it "may or may not escape ~ inline" do
        result = escaper.escape("~approx")
        expect(result).to eq("~approx").or include("\\~")
      end

      it "may or may not escape : in regular text" do
        result = escaper.escape("Note: something")
        expect(result).to eq("Note: something").or include("\\:")
      end

      it "may or may not escape ; in regular text" do
        result = escaper.escape("a; b")
        expect(result).to eq("a; b").or include("\\;")
      end

      it "may or may not escape /" do
        result = escaper.escape("and/or")
        expect(result).to eq("and/or").or include("\\/")
      end

      it "may or may not escape ," do
        result = escaper.escape("a, b, c")
        expect(result).to eq("a, b, c").or include("\\,")
      end

      it "may or may not escape ?" do
        result = escaper.escape("Why?")
        expect(result).to eq("Why?").or include("\\?")
      end

      it "may or may not escape @" do
        result = escaper.escape("@user")
        expect(result).to eq("@user").or include("\\@")
      end
    end

    # =========================================================================
    # Complex/Combined Cases
    # =========================================================================

    describe "complex combined cases" do
      it "escapes multiple syntax elements in one line" do
        input = "# Heading with *emphasis* and `code`"
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\*")
        expect(result).to include("\\`")
      end

      it "escapes multiline content with various syntax" do
        input = <<~MARKDOWN.chomp
          # Heading

          Some *emphasis* and a [link](url).

          - list item

          > quote
        MARKDOWN
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\*")
        expect(result).to include("\\[")
        expect(result).to include("\\-")
        expect(result).to include("\\>")
      end

      it "escapes nested emphasis" do
        input = "***bold and italic***"
        result = escaper.escape(input)
        expect(result.count("\\")).to eq(6)
      end

      it "escapes image inside link" do
        input = "[![alt](img.png)](url)"
        result = escaper.escape(input)
        # Must escape [ - that's enough to break the image syntax
        expect(result).to include("\\[")
        # May optionally escape ! too (false positive OK)
      end

      it "preserves text that needs no escaping" do
        input = "Just plain text with no special characters"
        result = escaper.escape(input)
        # May or may not add escapes, but should preserve original text content
        expect(result.gsub("\\", "")).to eq(input)
      end

      it "handles empty string" do
        expect(escaper.escape("")).to eq("")
      end

      it "handles unicode content" do
        input = "Héllo *wörld* with émphasis"
        result = escaper.escape(input)
        expect(result).to include("Héllo")
        expect(result).to include("wörld")
        expect(result).to include("\\*")
      end

      it "handles consecutive special characters" do
        input = "***"
        result = escaper.escape(input)
        # Must escape to prevent thematic break or emphasis
        expect(result).to include("\\")
      end

      it "handles real-world example: code snippet description" do
        input = "Use `Array#map` to transform [1, 2, 3]"
        result = escaper.escape(input)
        expect(result).to include("\\`")
        expect(result).to include("\\[")
      end

      it "handles real-world example: math expression" do
        input = "If x > 0 and y < 10, then *result* = x * y"
        result = escaper.escape(input)
        expect(result).to include("\\*")
      end

      it "handles real-world example: document with footnotes" do
        input = "This claim needs citation[^1] and this is ~~wrong~~ corrected."
        result = escaper.escape(input)
        expect(result).to include("\\[^1]")
        expect(result).to include("\\~\\~")
      end

      it "handles all extensions combined with core syntax" do
        input = "# Title with ~~deleted~~ and [^note]\n\n[^note]: The *footnote* text."
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\~\\~")
        expect(result).to include("\\[^note]")
        expect(result).to include("\\*")
      end

      it "handles table with formatted content" do
        input = "| **Bold** | *Italic* | ~~Strike~~ |"
        result = escaper.escape(input)
        expect(result).to include("\\|")
        expect(result).to include("\\*")
        expect(result).to include("\\~")
      end

      it "handles document with indented code and other syntax" do
        input = <<~DOC.chomp
          # Heading

          Some *emphasis* here.

              // code block
              var x = 1;

          Back to normal with [link](url).
        DOC
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\*")
        expect(result).to include("\\[")
        # Indented code should be escaped
        expect(result).not_to match(/\n {4}\/\//)
      end
    end

    # =========================================================================
    # Edge Cases
    # =========================================================================

    describe "edge cases" do
      it "handles nil input" do
        expect(escaper.escape(nil)).to eq("")
      end

      it "handles whitespace-only input" do
        expect(escaper.escape("   ")).to eq("   ")
        expect(escaper.escape("\t")).to eq("\t")
        expect(escaper.escape("\n")).to eq("\n")
        expect(escaper.escape("\n\n")).to eq("\n\n")
        expect(escaper.escape("  \n  ")).to eq("  \n  ")
      end

      it "handles CRLF line endings" do
        input = "# Heading\r\n- item"
        result = escaper.escape(input)
        expect(result).to include("\\#")
        expect(result).to include("\\-")
      end

      it "handles very long lines" do
        long_text = "a" * 10_000
        result = escaper.escape(long_text)
        expect(result).to eq(long_text)
      end

      it "handles text with existing escape sequences" do
        input = "\\* \\# \\> \\- \\`"
        result = escaper.escape(input)
        # Each existing backslash should be escaped
        expect(result.scan("\\\\").length).to be >= 5
      end

      it "handles multiple blank lines" do
        input = "para1\n\n\npara2"
        result = escaper.escape(input)
        expect(result).to eq("para1\n\n\npara2")
      end

      it "handles only newlines" do
        input = "\n\n\n"
        result = escaper.escape(input)
        expect(result).to eq("\n\n\n")
      end

      it "handles mixed indentation (4+ spaces converted to NBSP)" do
        nbsp = "\u00A0"
        input = "  text\n    more\n\tindented"
        result = escaper.escape(input)
        # 2-space indent preserved, 4-space and tab converted to NBSP
        expect(result).to eq("  text\n#{nbsp * 4}more\n#{nbsp * 4}indented")
      end
    end

    # =========================================================================
    # UTF-8 AND ENCODING TESTS
    # =========================================================================
    describe "UTF-8 handling" do
      it "preserves emoji" do
        # Use unicode escapes to avoid encoding issues
        result = escaper.escape("Hello \u{1F44B} *world*")
        expect(result).to include("\u{1F44B}")
        expect(result).to include("\\*world\\*")
      end

      it "preserves CJK characters" do
        result = escaper.escape("\u{65E5}\u{672C}\u{8A9E} *emphasis*")
        expect(result).to include("\u{65E5}\u{672C}\u{8A9E}")
        expect(result).to include("\\*emphasis\\*")
      end

      it "handles mixed scripts with markdown" do
        input = "# \u{0417}\u{0430}\u{0433}\u{043E}\u{043B}\u{043E}\u{0432}\u{043E}\u{043A}"
        result = escaper.escape(input)
        expect(result).to start_with("\\#")
      end

      it "handles 4-byte UTF-8 characters" do
        # Mathematical bold H
        result = escaper.escape("\u{1D573} *world*")
        expect(result).to include("\u{1D573}")
        expect(result).to include("\\*")
      end
    end

    describe "encoding preservation" do
      it "preserves UTF-8 encoding" do
        input = "Hello *world*"
        input = input.encode("UTF-8")
        result = escaper.escape(input)
        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it "handles ASCII-8BIT input" do
        input = "Hello *world*".b
        result = escaper.escape(input)
        # Result encoding depends on implementation, but should not raise
        expect(result).to include("\\*")
      end
    end
  end
end
