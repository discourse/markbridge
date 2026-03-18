# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "block quotes (>)" do
    context "when > is at line start (MUST escape)" do
      it "escapes > at line start followed by space" do
        expect(escaper.escape("> quote")).to eq("\\> quote")
      end

      it "escapes > at line start without following space" do
        expect(escaper.escape(">quote")).to eq("\\>quote")
      end

      it "escapes > with 1-3 spaces indent" do
        expect(escaper.escape("   > quote")).to eq("   \\> quote")
      end

      it "escapes standalone > at line start" do
        expect(escaper.escape(">")).to eq("\\>")
      end
    end

    context "when > is not at line start (MAY escape - false positives OK)" do
      it "may or may not escape > in middle of line" do
        result = escaper.escape("foo > bar")
        expect(result).to eq("foo > bar").or eq("foo \\> bar")
      end

      it "may or may not escape > as greater-than" do
        result = escaper.escape("5 > 3")
        expect(result).to eq("5 > 3").or eq("5 \\> 3")
      end
    end
  end
end
