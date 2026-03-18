# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "ordered list markers (digits + . or ))" do
    context "when digit(s) + . at line start followed by space (MUST escape)" do
      it "escapes 1. at line start" do
        expect(escaper.escape("1. First item")).to eq("1\\. First item")
      end

      it "escapes multi-digit numbers" do
        expect(escaper.escape("123. Item")).to eq("123\\. Item")
      end

      it "escapes large numbers (Discourse has no length limit)" do
        expect(escaper.escape("1234567890. Item")).to eq("1234567890\\. Item")
      end

      it "escapes very large numbers" do
        expect(escaper.escape("99999999999999. Item")).to eq("99999999999999\\. Item")
      end

      it "escapes 0. at line start" do
        expect(escaper.escape("0. Item")).to eq("0\\. Item")
      end

      it "escapes with 1-3 spaces indent" do
        expect(escaper.escape("   1. Item")).to eq("   1\\. Item")
      end
    end

    context "when digit(s) + ) at line start followed by space (MUST escape)" do
      it "escapes 1) at line start" do
        expect(escaper.escape("1) First item")).to eq("1\\) First item")
      end

      it "escapes multi-digit with )" do
        expect(escaper.escape("99) Item")).to eq("99\\) Item")
      end

      it "escapes large numbers with )" do
        expect(escaper.escape("1234567890) Item")).to eq("1234567890\\) Item")
      end
    end

    context "when not an ordered list marker (MAY escape - false positives OK)" do
      it "may or may not escape number + . not followed by space" do
        result = escaper.escape("1.Item")
        expect(result).to eq("1.Item").or eq("1\\.Item")
      end

      it "may or may not escape number + . in middle of line" do
        result = escaper.escape("See section 1. for details")
        expect(result).to eq("See section 1. for details").or include("1\\.")
      end

      it "may or may not escape decimal numbers" do
        result = escaper.escape("Price is 1.99")
        expect(result).to eq("Price is 1.99").or eq("Price is 1\\.99")
      end
    end
  end
end
