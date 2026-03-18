# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "ATX headings (#)" do
    context "when # is at line start followed by space (MUST escape)" do
      it "escapes single # followed by space" do
        expect(escaper.escape("# Heading")).to eq("\\# Heading")
      end

      it "escapes ## followed by space" do
        expect(escaper.escape("## Heading")).to eq("\\## Heading")
      end

      it "escapes up to 6 # characters" do
        expect(escaper.escape("###### Heading")).to eq("\\###### Heading")
      end

      it "escapes # followed by tab" do
        expect(escaper.escape("#\tHeading")).to eq("\\#\tHeading")
      end

      it "escapes # at end of line (empty heading)" do
        expect(escaper.escape("#")).to eq("\\#")
      end
    end

    context "when # is at line start with 1-3 spaces indent (MUST escape)" do
      it "escapes # with 1 space indent" do
        expect(escaper.escape(" # Heading")).to eq(" \\# Heading")
      end

      it "escapes # with 3 spaces indent" do
        expect(escaper.escape("   # Heading")).to eq("   \\# Heading")
      end
    end

    context "when # is not special (MAY escape - false positives OK)" do
      it "may or may not escape # not followed by space" do
        result = escaper.escape("#hashtag")
        expect(result).to eq("#hashtag").or eq("\\#hashtag")
      end

      it "may or may not escape more than 6 # characters" do
        result = escaper.escape("####### Not heading")
        expect(result).to eq("####### Not heading").or start_with("\\#")
      end

      it "may or may not escape # in middle of line" do
        result = escaper.escape("foo # bar")
        expect(result).to eq("foo # bar").or eq("foo \\# bar")
      end
    end

    it "escapes # at start of new line in multiline text" do
      expect(escaper.escape("Some text\n# Heading")).to eq("Some text\n\\# Heading")
    end
  end
end
