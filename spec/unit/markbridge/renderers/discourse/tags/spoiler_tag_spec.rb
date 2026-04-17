# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::SpoilerTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "wraps content in [spoiler]...[/spoiler] when no title is set" do
      element = Markbridge::AST::Spoiler.new
      element << Markbridge::AST::Text.new("hidden")

      expect(tag.render(element, interface)).to eq("[spoiler]hidden[/spoiler]")
    end

    it "uses [spoiler=title] form when a title is set" do
      element = Markbridge::AST::Spoiler.new(title: "Click me")
      element << Markbridge::AST::Text.new("hidden")

      expect(tag.render(element, interface)).to eq("[spoiler=Click me]hidden[/spoiler]")
    end

    let(:element_class) { Markbridge::AST::Spoiler }
    it_behaves_like "a tag that propagates parent context"
  end
end
