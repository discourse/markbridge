# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Builders::ListItemBuilder do
  let(:builder) { described_class.new }

  describe "#build" do
    context "with single-line content" do
      it "formats unordered list item" do
        result = builder.build("simple text", marker: "- ", indent: "")
        expect(result).to eq("- simple text\n")
      end

      it "formats ordered list item" do
        result = builder.build("simple text", marker: "1. ", indent: "")
        expect(result).to eq("1. simple text\n")
      end

      it "applies indentation" do
        result = builder.build("nested item", marker: "- ", indent: "  ")
        expect(result).to eq("  - nested item\n")
      end

      it "applies multiple levels of indentation" do
        result = builder.build("deep item", marker: "1. ", indent: "     ")
        expect(result).to eq("     1. deep item\n")
      end
    end

    context "with multi-line content" do
      it "indents continuation lines for unordered list" do
        result = builder.build("line1\nline2\nline3", marker: "- ", indent: "")
        expect(result).to eq("- line1\n  line2\n  line3\n")
      end

      it "indents continuation lines for ordered list" do
        result = builder.build("line1\nline2\nline3", marker: "1. ", indent: "")
        expect(result).to eq("1. line1\n  line2\n  line3\n")
      end

      it "applies base indentation to all lines" do
        result = builder.build("line1\nline2", marker: "- ", indent: "  ")
        expect(result).to eq("  - line1\n    line2\n")
      end

      it "handles deeply nested multi-line content" do
        result = builder.build("first\nsecond", marker: "1. ", indent: "     ")
        expect(result).to eq("     1. first\n       second\n")
      end
    end

    context "with blank lines (paragraph breaks)" do
      it "preserves blank lines within text content" do
        result = builder.build("First paragraph\n\nSecond paragraph", marker: "- ", indent: "")
        expect(result).to eq("- First paragraph\n  \n  Second paragraph\n")
      end

      it "preserves blank lines with indentation" do
        result = builder.build("Para 1\n\nPara 2", marker: "- ", indent: "  ")
        expect(result).to eq("  - Para 1\n    \n    Para 2\n")
      end

      it "preserves multiple blank lines" do
        result = builder.build("Text\n\n\nMore text", marker: "- ", indent: "")
        expect(result).to eq("- Text\n  \n  \n  More text\n")
      end
    end

    context "with nested list items" do
      it "does not add extra indentation to nested list markers" do
        content = "parent text\n  - nested item"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- parent text\n  - nested item\n")
      end

      it "detects ordered list markers" do
        content = "parent\n  1. nested"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- parent\n  1. nested\n")
      end

      it "handles nested lists with base indentation" do
        content = "text\n    - deep nested"
        result = builder.build(content, marker: "1. ", indent: "  ")
        expect(result).to eq("  1. text\n    - deep nested\n")
      end

      it "skips blank lines before nested list items" do
        content = "parent text\n\n  - nested item"
        result = builder.build(content, marker: "- ", indent: "")
        # Blank line before nested list is structural, not content, so it's skipped
        expect(result).to eq("- parent text\n  - nested item\n")
      end
    end

    context "with complex mixed content" do
      it "handles text, blank lines, and nested lists together" do
        content = "First line\n\nSecond line\n  - nested\nThird line"
        result = builder.build(content, marker: "- ", indent: "")
        # Text after nested list still gets continuation indent
        expect(result).to eq("- First line\n  \n  Second line\n  - nested\n  Third line\n")
      end

      it "handles ordered parent with unordered nested" do
        content = "ordered parent\n   - unordered nested\nmore parent"
        result = builder.build(content, marker: "1. ", indent: "")
        # Text after nested list still gets continuation indent
        expect(result).to eq("1. ordered parent\n   - unordered nested\n  more parent\n")
      end

      it "preserves exact indentation of nested items" do
        content = "text\n     - deeply indented nested"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- text\n     - deeply indented nested\n")
      end
    end

    context "with blank lines around nested list items" do
      # Kills `[idx + 1]` → `[idx - 1]` / `[1]` / `[-1]` mutations in
      # handle_empty_line. Requires a blank line whose PREVIOUS line
      # is a nested list marker but whose NEXT line is plain text.
      # Under `[idx - 1]` the mutation would look backward at the
      # nested marker and skip the blank; original looks forward at
      # plain text and preserves the paragraph-break indent.
      it "preserves blank line after nested list when followed by plain text" do
        content = "parent\n  - nested\n\nafter"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- parent\n  - nested\n  \n  after\n")
      end

      # Kills `\d+\.` → `\d\.` mutation on the nested-list regex in
      # format_continuation_line / handle_empty_line. Multi-digit
      # ordered marker (`10.`) only matches with `\d+`, not `\d`.
      it "detects multi-digit ordered-list markers as nested" do
        content = "parent\n  10. tenth"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- parent\n  10. tenth\n")
      end

      # Kills `\A\s*` → `\A\s+` mutation on the nested-list regex.
      # An unindented marker as a continuation line is atypical but
      # the regex was written to allow zero leading whitespace; the
      # mutation requires at least one.
      it "treats unindented list marker in continuation as nested (zero leading space)" do
        content = "text\n- unindented"
        result = builder.build(content, marker: "- ", indent: "")
        # Under \A\s+ the line would get continuation_indent prepended
        # instead of being kept as-is.
        expect(result).to eq("- text\n- unindented\n")
      end

      # Kills `continuation_lines[idx + 1]` → `continuation_lines[1]`
      # mutation. Requires the blank line at idx > 0 where `[1]` gives
      # a different element than `[idx + 1]`. With blank at idx=1,
      # `[1]` would be the blank itself (no match → preserve indent),
      # while `[idx + 1]` points to the nested marker (match → skip).
      it "skips blank line at idx>0 when followed by nested marker (forward lookup)" do
        content = "a\nb\n\n  - nested\nc"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- a\n  b\n  - nested\n  c\n")
      end

      # Kills `\A\s*` → `\A\s+` mutation on handle_empty_line's regex.
      # Next line is an unindented nested marker (zero leading space);
      # `\s+` would require at least one space and fail to match.
      it "skips blank line before unindented nested marker" do
        content = "a\n\n- nested"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- a\n- nested\n")
      end

      # Kills `(?:-|\d+\.)` → `(?:-)` / `\d\.` / `\D+\.` mutations.
      # Blank line before a multi-digit ordered-marker nested item.
      # `\d` (single) would fail to match `10.`. `\D+` would require
      # non-digits. `(?:-)` drops ordered entirely.
      it "skips blank line before multi-digit ordered nested marker" do
        content = "a\n\n  10. nested"
        result = builder.build(content, marker: "- ", indent: "")
        expect(result).to eq("- a\n  10. nested\n")
      end
    end

    context "with edge cases" do
      it "handles empty content" do
        result = builder.build("", marker: "- ", indent: "")
        expect(result).to eq("- \n")
      end

      it "handles content that is only whitespace" do
        result = builder.build("   ", marker: "- ", indent: "")
        expect(result).to eq("-    \n")
      end

      it "handles content that is only newlines" do
        result = builder.build("\n\n", marker: "- ", indent: "")
        # Empty content with only newlines is treated as empty
        expect(result).to eq("- \n")
      end

      it "handles very long indentation" do
        long_indent = "          "
        result = builder.build("text", marker: "- ", indent: long_indent)
        expect(result).to eq("#{long_indent}- text\n")
      end
    end
  end
end
