# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "fenced code block markers at line start" do
    context "when 3+ backticks at line start (MUST escape)" do
      # We escape ALL backticks in a fence to prevent code span interpretation
      # e.g., \```` would be \` + ``` (code span start), so we use \`\`\`\`

      it "escapes ``` at line start - all backticks escaped" do
        expect(escaper.escape("```")).to eq("\\`\\`\\`")
      end

      it "escapes ``` with info string - all backticks escaped" do
        expect(escaper.escape("```ruby")).to eq("\\`\\`\\`ruby")
      end

      it "escapes ```` (4+ backticks) - all backticks escaped" do
        expect(escaper.escape("````")).to eq("\\`\\`\\`\\`")
      end

      it "escapes ``` with 1-3 spaces indent - all backticks escaped" do
        expect(escaper.escape("   ```")).to eq("   \\`\\`\\`")
      end

      it "escapes nested fence patterns correctly" do
        # This was a known failure case - nested fences with different lengths
        input = "````\naaa\n```\n``````"
        result = escaper.escape(input)
        # Each fence line should have all backticks escaped
        expect(result).to include("\\`\\`\\`\\`")
        expect(result).to include("\\`\\`\\`\n")
        expect(result).to include("\\`\\`\\`\\`\\`\\`")
      end
    end

    context "when 3+ tildes at line start (MUST escape)" do
      it "escapes ~~~ at line start" do
        expect(escaper.escape("~~~")).to eq("\\~~~")
      end

      it "escapes ~~~ with info string" do
        expect(escaper.escape("~~~python")).to eq("\\~~~python")
      end
    end

    context "when fence markers not at line start (MAY escape - false positives OK)" do
      it "may or may not escape ``` in middle of line" do
        result = escaper.escape("some ``` text")
        expect(result).to eq("some ``` text").or include("\\`")
      end
    end
  end
end
