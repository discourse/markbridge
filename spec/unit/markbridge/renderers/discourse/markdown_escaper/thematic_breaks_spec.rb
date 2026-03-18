# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "thematic breaks (---, ***, ___)" do
    # NOTE: Discourse converts -- to &ndash;, so we must escape each character
    # individually (e.g., \-\-\-) to prevent \-&ndash; output

    context "when 3+ identical characters form thematic break (MUST escape)" do
      it "escapes --- with each dash escaped" do
        expect(escaper.escape("---")).to eq("\\-\\-\\-")
      end

      it "escapes *** with each asterisk escaped" do
        expect(escaper.escape("***")).to eq("\\*\\*\\*")
      end

      it "escapes ___ with each underscore escaped" do
        expect(escaper.escape("___")).to eq("\\_\\_\\_")
      end

      it "escapes with spaces between characters" do
        expect(escaper.escape("- - -")).to eq("\\- \\- \\-")
      end

      it "escapes many dashes with each escaped" do
        expect(escaper.escape("----------")).to eq("\\-\\-\\-\\-\\-\\-\\-\\-\\-\\-")
      end

      it "escapes many asterisks with each escaped" do
        expect(escaper.escape("*****")).to eq("\\*\\*\\*\\*\\*")
      end

      it "escapes many underscores with each escaped" do
        expect(escaper.escape("_____")).to eq("\\_\\_\\_\\_\\_")
      end

      it "escapes with 1-3 spaces indent" do
        expect(escaper.escape("   ---")).to eq("   \\-\\-\\-")
      end

      it "escapes with trailing spaces" do
        expect(escaper.escape("---   ")).to eq("\\-\\-\\-   ")
      end

      it "escapes spaced asterisks" do
        expect(escaper.escape("* * *")).to eq("\\* \\* \\*")
      end

      it "escapes spaced underscores" do
        expect(escaper.escape("_ _ _")).to eq("\\_ \\_ \\_")
      end
    end

    context "when not a thematic break (MAY escape - false positives OK)" do
      it "may or may not escape fewer than 3 characters" do
        result = escaper.escape("--")
        # Note: -- should probably be escaped anyway due to Discourse ndash conversion
        expect(result).to eq("--").or eq("\\-\\-")
      end

      it "may or may not escape mixed characters" do
        result = escaper.escape("-*-")
        expect(result).to eq("-*-").or include("\\")
      end
    end
  end
end
