# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::EmailTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders a markdown mailto link when an address is set" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("Contact us")

      expect(tag.render(element, interface)).to eq("[Contact us](mailto:[email protected])")
    end

    it "uses the address verbatim, not html-escaped" do
      element = Markbridge::AST::Email.new(address: "[email protected]")
      element << Markbridge::AST::Text.new("link")

      expect(tag.render(element, interface)).to eq("[link](mailto:[email protected])")
    end

    it "returns just the content when no address is set" do
      element = Markbridge::AST::Email.new
      element << Markbridge::AST::Text.new("text")

      expect(tag.render(element, interface)).to eq("text")
    end

    let(:element_class) { Markbridge::AST::Email }
    it_behaves_like "a tag that propagates parent context"
  end
end
