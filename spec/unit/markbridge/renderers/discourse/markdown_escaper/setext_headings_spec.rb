# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper do
  subject(:escaper) { described_class.new }

  describe "setext heading underlines (=, -)" do
    # NOTE: Discourse converts -- to &ndash;, so we must escape each dash
    # individually to prevent issues like \-&ndash;

    context "when = or - line follows paragraph (MUST escape)" do
      it "escapes = underline after paragraph" do
        text = "Heading\n==="
        expect(escaper.escape(text)).to eq("Heading\n\\=\\=\\=")
      end

      it "escapes - underline after paragraph with each dash escaped" do
        text = "Heading\n---"
        expect(escaper.escape(text)).to eq("Heading\n\\-\\-\\-")
      end

      it "escapes single = after paragraph" do
        text = "Heading\n="
        expect(escaper.escape(text)).to eq("Heading\n\\=")
      end

      it "escapes single - after paragraph" do
        text = "Heading\n-"
        expect(escaper.escape(text)).to eq("Heading\n\\-")
      end

      it "escapes long = underline" do
        text = "Heading\n======"
        expect(escaper.escape(text)).to eq("Heading\n\\=\\=\\=\\=\\=\\=")
      end

      it "escapes long - underline with each dash escaped" do
        text = "Heading\n------"
        expect(escaper.escape(text)).to eq("Heading\n\\-\\-\\-\\-\\-\\-")
      end
    end

    context "when = is standalone (MAY escape - false positives OK)" do
      it "may or may not escape standalone ===" do
        result = escaper.escape("===")
        expect(result).to eq("===").or eq("\\=\\=\\=")
      end
    end

    context "when setext underline follows escaped bracket line (MUST escape)" do
      # Lines starting with [ get escaped to \[, becoming paragraph content
      # This means === or --- after them would create setext headings

      it "escapes === after escaped link reference definition" do
        input = "[foo]: /url\n==="
        result = escaper.escape(input)
        expect(result).to include("\\[foo]")
        expect(result).to include("\\=\\=\\=")
      end

      it "escapes --- after escaped link reference definition" do
        input = "[foo]: /url\n---"
        result = escaper.escape(input)
        expect(result).to include("\\[foo]")
        expect(result).to include("\\-\\-\\-")
      end

      it "escapes === after escaped bracket link" do
        input = "[link](url)\n==="
        result = escaper.escape(input)
        expect(result).to include("\\[link]")
        expect(result).to include("\\=\\=\\=")
      end
    end
  end
end
