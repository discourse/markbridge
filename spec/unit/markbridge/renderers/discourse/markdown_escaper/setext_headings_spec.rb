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

    context "when the = line has no paragraph before it (MUST escape)" do
      # The escaper only sees one text fragment. The renderer can place
      # that fragment after a paragraph line, so a `=`-only line is always
      # escaped. Discourse shows `\=` as a literal `=`.
      it "escapes a standalone ===" do
        expect(escaper.escape("===")).to eq("\\=\\=\\=")
      end

      it "escapes === after a blank line" do
        expect(escaper.escape("Text\n\n===")).to eq("Text\n\n\\=\\=\\=")
      end

      it "escapes === after a list item" do
        expect(escaper.escape("- item\n===")).to eq("\\- item\n\\=\\=\\=")
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
