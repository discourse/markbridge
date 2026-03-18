# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "entity references (&)" do
    context "when & forms valid entity (MUST escape)" do
      it "escapes valid named entity &amp;" do
        expect(escaper.escape("&amp;")).to eq("\\&amp;")
      end

      it "escapes numeric entity" do
        expect(escaper.escape("&#38;")).to eq("\\&#38;")
      end

      it "escapes hex entity" do
        expect(escaper.escape("&#x26;")).to eq("\\&#x26;")
      end

      it "escapes &nbsp;" do
        expect(escaper.escape("&nbsp;")).to eq("\\&nbsp;")
      end

      it "escapes &copy;" do
        expect(escaper.escape("&copy;")).to eq("\\&copy;")
      end

      it "escapes &lt; and &gt;" do
        expect(escaper.escape("&lt;&gt;")).to eq("\\&lt;\\&gt;")
      end
    end

    context "when & does not form valid entity (MAY escape - false positives OK)" do
      it "may or may not escape & not followed by valid entity" do
        result = escaper.escape("AT&T")
        expect(result).to eq("AT&T").or eq("AT\\&T")
      end

      it "may or may not escape & followed by space" do
        result = escaper.escape("bread & butter")
        expect(result).to eq("bread & butter").or eq("bread \\& butter")
      end

      it "may or may not escape invalid entity reference" do
        result = escaper.escape("&invalid;")
        expect(result).to eq("&invalid;").or eq("\\&invalid;")
      end

      it "may or may not escape & at end of text" do
        result = escaper.escape("foo&")
        expect(result).to eq("foo&").or eq("foo\\&")
      end
    end
  end
end
