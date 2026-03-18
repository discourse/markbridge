# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "backslash (\\)" do
    context "when \\ precedes ASCII punctuation (MUST escape)" do
      it "escapes backslash before *" do
        result = escaper.escape("\\*")
        expect(result).to eq("\\\\*").or eq("\\\\\\*")
      end

      it "escapes backslash before [" do
        result = escaper.escape("\\[")
        expect(result).to eq("\\\\[").or eq("\\\\\\[")
      end

      it "escapes backslash before \\" do
        expect(escaper.escape("\\\\")).to eq("\\\\\\\\")
      end

      it "escapes backslash before #" do
        result = escaper.escape("\\#")
        expect(result).to eq("\\\\#").or eq("\\\\\\#")
      end
    end

    context "when \\ is at end of line (hard break - MUST escape)" do
      it "escapes backslash at end of line" do
        expect(escaper.escape("foo\\\nbar")).to eq("foo\\\\\nbar")
      end
    end

    context "when \\ is before non-punctuation (MAY escape - false positives OK)" do
      it "may or may not escape \\ before letter" do
        result = escaper.escape("\\n")
        expect(result).to eq("\\n").or eq("\\\\n")
      end

      it "may or may not escape \\ in path" do
        result = escaper.escape("C:\\Users")
        expect(result).to eq("C:\\Users").or eq("C:\\\\Users")
      end
    end
  end
end
