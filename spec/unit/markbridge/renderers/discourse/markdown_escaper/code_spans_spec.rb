# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "code spans (`)" do
    context "when backticks can form code span (MUST escape)" do
      it "escapes single backticks around text" do
        expect(escaper.escape("`code`")).to eq("\\`code\\`")
      end

      it "escapes double backticks" do
        expect(escaper.escape("``code``")).to eq("\\`\\`code\\`\\`")
      end

      it "escapes backticks in middle of text" do
        expect(escaper.escape("use `code` here")).to eq("use \\`code\\` here")
      end

      it "escapes triple backticks inline" do
        expect(escaper.escape("```inline```")).to eq("\\`\\`\\`inline\\`\\`\\`")
      end
    end

    context "when backticks are unmatched (MAY escape - false positives OK)" do
      it "may or may not escape unmatched opening backtick" do
        result = escaper.escape("`unmatched")
        expect(result).to eq("`unmatched").or eq("\\`unmatched")
      end

      it "may or may not escape unmatched closing backtick" do
        result = escaper.escape("unmatched`")
        expect(result).to eq("unmatched`").or eq("unmatched\\`")
      end
    end
  end
end
