# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::SizeTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "wraps content in a styled span with font-size when size is set" do
      element = Markbridge::AST::Size.new(size: "20")
      element << Markbridge::AST::Text.new("big")

      expect(tag.render(element, interface)).to eq('<span style="font-size: 20px">big</span>')
    end

    it "returns just the content when no size is set" do
      element = Markbridge::AST::Size.new
      element << Markbridge::AST::Text.new("plain")

      expect(tag.render(element, interface)).to eq("plain")
    end

    let(:element_class) { Markbridge::AST::Size }
    it_behaves_like "a tag that propagates parent context"
  end

  describe "#html_mode_aware?" do
    it "returns true" do
      expect(described_class.new.html_mode_aware?).to be true
    end
  end
end
