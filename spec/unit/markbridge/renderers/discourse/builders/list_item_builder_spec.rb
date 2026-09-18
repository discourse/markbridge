# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Builders::ListItemBuilder do
  let(:builder) { described_class.new }

  describe "#build" do
    context "with single-line content" do
      it "puts an unordered marker in front of the content" do
        expect(builder.build("simple text", marker: "- ")).to eq("- simple text\n")
      end

      it "puts an ordered marker in front of the content" do
        expect(builder.build("simple text", marker: "1. ")).to eq("1. simple text\n")
      end
    end

    context "with multi-line content" do
      it "indents continuation lines by the width of an unordered marker" do
        expect(builder.build("line1\nline2\nline3", marker: "- ")).to eq(
          "- line1\n  line2\n  line3\n",
        )
      end

      it "indents continuation lines by the width of an ordered marker" do
        expect(builder.build("line1\nline2\nline3", marker: "1. ")).to eq(
          "1. line1\n   line2\n   line3\n",
        )
      end

      it "indents by the full width of a wider ordered marker" do
        expect(builder.build("line1\nline2", marker: "10. ")).to eq("10. line1\n    line2\n")
      end
    end

    context "with content that carries its own indentation" do
      it "adds the marker width on top of the indentation a nested line already has" do
        expect(builder.build("parent text\n  - nested item", marker: "- ")).to eq(
          "- parent text\n    - nested item\n",
        )
      end

      it "indents a line that looks like a list marker like any other line" do
        expect(builder.build("parent\n- sibling", marker: "- ")).to eq("- parent\n  - sibling\n")
      end

      it "indents a line that looks like an ordered marker like any other line" do
        expect(builder.build("parent\n1. sibling", marker: "1. ")).to eq(
          "1. parent\n   1. sibling\n",
        )
      end

      it "keeps the relative distance between two indented lines" do
        expect(builder.build("a\n  b\n    c", marker: "- ")).to eq("- a\n    b\n      c\n")
      end
    end

    context "with blank lines" do
      it "leaves a blank line empty instead of filling it with indentation" do
        expect(builder.build("first\n\nsecond", marker: "- ")).to eq("- first\n\n  second\n")
      end

      it "leaves several blank lines in a row empty" do
        expect(builder.build("a\n\n\nb", marker: "- ")).to eq("- a\n\n\n  b\n")
      end

      it "indents a whitespace-only line, which is not empty" do
        expect(builder.build("a\n \nb", marker: "- ")).to eq("- a\n   \n  b\n")
      end
    end

    context "with edge cases" do
      it "emits a bare marker for empty content" do
        expect(builder.build("", marker: "- ")).to eq("- \n")
      end

      it "keeps whitespace-only content on the marker line" do
        expect(builder.build("   ", marker: "- ")).to eq("-    \n")
      end

      it "treats content that is only newlines as empty" do
        expect(builder.build("\n\n", marker: "- ")).to eq("- \n")
      end

      it "drops the trailing newline of the content and adds exactly one" do
        expect(builder.build("a\nb\n", marker: "- ")).to eq("- a\n  b\n")
      end
    end
  end
end
