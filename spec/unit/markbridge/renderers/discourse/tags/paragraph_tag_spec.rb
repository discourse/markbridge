# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ParagraphTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "takes spaces off the start of the content" do
      paragraph = Markbridge::AST::Paragraph.new << Markbridge::AST::Text.new("   x")

      expect(tag.render(paragraph, interface)).to eq("\n\nx\n\n")
    end

    it "keeps a no-break space at the start of the content" do
      paragraph = Markbridge::AST::Paragraph.new << Markbridge::AST::Text.new("\u00A0x")

      expect(tag.render(paragraph, interface)).to eq("\n\n\u00A0x\n\n")
    end

    it "brackets content with leading and trailing blank lines" do
      element = Markbridge::AST::Paragraph.new
      element << Markbridge::AST::Text.new("hello")

      expect(tag.render(element, interface)).to eq("\n\nhello\n\n")
    end

    let(:element_class) { Markbridge::AST::Paragraph }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { html_context }

      it "renders a paragraph with nothing visible to nothing" do
        empty = Markbridge::AST::Paragraph.new
        blank = Markbridge::AST::Paragraph.new << Markbridge::AST::Text.new(" \n")

        expect(tag.render(empty, interface)).to eq("")
        expect(tag.render(blank, interface)).to eq("")
      end

      it "wraps content in <p> with no trailing blank line" do
        element = Markbridge::AST::Paragraph.new
        element << Markbridge::AST::Text.new("hello")

        expect(tag.render(element, interface)).to eq("<p>hello</p>")
      end

      context "when inside a TableCell" do
        let(:context) do
          Markbridge::Renderers::Discourse::RenderContext.new(
            [Markbridge::AST::TableCell.new],
            html_mode: true,
          )
        end

        it "keeps the <p>, without it the paragraph runs into the text next to it" do
          element = Markbridge::AST::Paragraph.new
          element << Markbridge::AST::Text.new("hello")

          expect(tag.render(element, interface)).to eq("<p>hello</p>")
        end
      end
    end
  end
end
