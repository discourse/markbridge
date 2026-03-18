# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "strikethrough (~~)" do
    context "when ~~ forms strikethrough (MUST escape)" do
      it "escapes ~~text~~" do
        expect(escaper.escape("~~deleted~~")).to eq("\\~\\~deleted\\~\\~")
      end

      it "escapes strikethrough in sentence" do
        expect(escaper.escape("This is ~~deleted~~ text.")).to eq(
          "This is \\~\\~deleted\\~\\~ text.",
        )
      end

      it "escapes strikethrough with multiple words" do
        expect(escaper.escape("~~multiple words deleted~~")).to eq(
          "\\~\\~multiple words deleted\\~\\~",
        )
      end

      it "escapes strikethrough at start of line" do
        expect(escaper.escape("~~start~~ of line")).to eq("\\~\\~start\\~\\~ of line")
      end

      it "escapes strikethrough at end of line" do
        expect(escaper.escape("end of ~~line~~")).to eq("end of \\~\\~line\\~\\~")
      end

      it "escapes multiple strikethroughs" do
        input = "~~first~~ and ~~second~~"
        result = escaper.escape(input)
        expect(result).to eq("\\~\\~first\\~\\~ and \\~\\~second\\~\\~")
      end

      it "escapes strikethrough combined with other formatting" do
        input = "**~~bold and deleted~~**"
        result = escaper.escape(input)
        expect(result).to include("\\~\\~")
        expect(result).to include("\\*\\*")
      end
    end

    context "when ~ is not strikethrough (MAY escape - false positives OK)" do
      it "may or may not escape single ~" do
        result = escaper.escape("~approximately")
        expect(result).to eq("~approximately").or eq("\\~approximately")
      end

      it "may or may not escape ~ surrounded by spaces" do
        result = escaper.escape("a ~ b")
        expect(result).to eq("a ~ b").or eq("a \\~ b")
      end

      it "may or may not escape unmatched ~~" do
        result = escaper.escape("~~unmatched")
        expect(result).to eq("~~unmatched").or include("\\~")
      end

      it "may or may not escape ~~ with spaces (non-flanking)" do
        result = escaper.escape("~~ spaced ~~")
        expect(result).to eq("~~ spaced ~~").or include("\\~")
      end
    end
  end
end
