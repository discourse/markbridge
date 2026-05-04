# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ParagraphTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "appends two newlines after the content (paragraph break)" do
      element = Markbridge::AST::Paragraph.new
      element << Markbridge::AST::Text.new("hello")

      expect(tag.render(element, interface)).to eq("hello\n\n")
    end

    let(:element_class) { Markbridge::AST::Paragraph }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

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

        it "drops the <p> wrapper since the surrounding <td> already provides block context" do
          element = Markbridge::AST::Paragraph.new
          element << Markbridge::AST::Text.new("hello")

          expect(tag.render(element, interface)).to eq("hello")
        end
      end
    end
  end

  describe "#html_mode_aware?" do
    it "returns true" do
      expect(described_class.new.html_mode_aware?).to be true
    end
  end
end
