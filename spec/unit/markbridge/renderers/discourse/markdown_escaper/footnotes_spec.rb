# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "footnotes" do
    context "when encountering footnote references (MUST escape)" do
      it "escapes simple footnote reference" do
        expect(escaper.escape("Here is a footnote reference,[^1] and more text.")).to eq(
          "Here is a footnote reference,\\[^1] and more text.",
        )
      end

      it "escapes named footnote reference" do
        expect(escaper.escape("See this,[^longnote] for details.")).to eq(
          "See this,\\[^longnote] for details.",
        )
      end

      it "escapes multiple footnote references" do
        input = "First,[^1] second,[^2] and third.[^3]"
        result = escaper.escape(input)
        expect(result).to eq("First,\\[^1] second,\\[^2] and third.\\[^3]")
      end

      it "escapes footnote reference with hyphen in name" do
        expect(escaper.escape("Reference[^my-note] here.")).to eq("Reference\\[^my-note] here.")
      end

      it "escapes footnote reference with underscore in name" do
        result = escaper.escape("Reference[^my_note] here.")
        # Must escape [ to break footnote, underscore escaping is acceptable (false positive)
        expect(result).to start_with("Reference\\[^my")
        expect(result).to end_with("note] here.").or end_with("note\\] here.")
      end
    end

    context "when footnote definitions are at line start (MUST escape)" do
      it "escapes simple footnote definition" do
        result = escaper.escape("[^1]: Here is the footnote.")
        # Must escape opening bracket
        expect(result).to start_with("\\[^1")
        expect(result).to include("Here is the footnote.")
      end

      it "escapes named footnote definition" do
        result = escaper.escape("[^longnote]: Here's one with multiple blocks.")
        expect(result).to start_with("\\[^longnote")
      end

      it "escapes footnote definition with 1-3 spaces indent" do
        result = escaper.escape("   [^1]: Indented footnote.")
        expect(result).to start_with("   \\[^1")
      end

      it "escapes multiline footnote definition" do
        input = <<~MARKDOWN.chomp
          [^longnote]: Here's one with multiple blocks.

              Subsequent paragraphs are indented to show that they
          belong to the previous footnote.
        MARKDOWN
        result = escaper.escape(input)
        expect(result).to start_with("\\[^longnote")
      end
    end

    context "when combining footnote references and definitions" do
      it "escapes complete footnote example" do
        input = <<~MARKDOWN.chomp
          Here is a footnote reference,[^1] and another.[^longnote]

          [^1]: Here is the footnote.

          [^longnote]: Here's one with multiple blocks.

              Subsequent paragraphs are indented to show that they
          belong to the previous footnote.
        MARKDOWN
        result = escaper.escape(input)
        expect(result).to include("\\[^1]")
        expect(result).to include("\\[^longnote]")
      end
    end

    context "when [^ does not form footnote (MAY escape - false positives OK)" do
      it "may or may not escape [^ not followed by label and ]" do
        result = escaper.escape("Use [^ for footnotes")
        expect(result).to eq("Use [^ for footnotes").or include("\\[")
      end

      it "may or may not escape ^ outside brackets" do
        result = escaper.escape("x^2 is x squared")
        expect(result).to eq("x^2 is x squared").or include("\\^")
      end
    end
  end
end
