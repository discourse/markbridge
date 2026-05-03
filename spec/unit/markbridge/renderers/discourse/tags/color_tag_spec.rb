# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ColorTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "wraps content in a styled span when color is set" do
      element = Markbridge::AST::Color.new(color: "red")
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq('<span style="color: red">hi</span>')
    end

    it "passes the color value through verbatim" do
      element = Markbridge::AST::Color.new(color: "#ff0000")
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq('<span style="color: #ff0000">hi</span>')
    end

    it "returns just the content when no color is set" do
      element = Markbridge::AST::Color.new
      element << Markbridge::AST::Text.new("hi")

      expect(tag.render(element, interface)).to eq("hi")
    end

    let(:element_class) { Markbridge::AST::Color }
    it_behaves_like "a tag that propagates parent context"
  end

  describe "#html_mode_aware?" do
    it "returns true" do
      expect(described_class.new.html_mode_aware?).to be true
    end
  end
end
