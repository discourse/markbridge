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
  end
end
