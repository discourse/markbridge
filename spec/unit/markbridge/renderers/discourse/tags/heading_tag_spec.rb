# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::HeadingTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders an h1 with one # prefix and a trailing blank line" do
      element = Markbridge::AST::Heading.new(level: 1)
      element << Markbridge::AST::Text.new("Title")

      expect(tag.render(element, interface)).to eq("# Title\n\n")
    end

    it "renders an h6 with six # prefixes" do
      element = Markbridge::AST::Heading.new(level: 6)
      element << Markbridge::AST::Text.new("Title")

      expect(tag.render(element, interface)).to eq("###### Title\n\n")
    end

    it "renders an h3 with exactly three # prefixes" do
      element = Markbridge::AST::Heading.new(level: 3)
      element << Markbridge::AST::Text.new("Title")

      expect(tag.render(element, interface)).to eq("### Title\n\n")
    end

    let(:element_class) { Markbridge::AST::Heading }
    let(:element_factory) { Markbridge::AST::Heading.new(level: 2) }
    it_behaves_like "a tag that propagates parent context"
  end
end
