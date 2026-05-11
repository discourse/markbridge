# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::HeadingTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders an h1 with one # prefix and blank-line bracketing" do
      element = Markbridge::AST::Heading.new(level: 1)
      element << Markbridge::AST::Text.new("Title")

      expect(tag.render(element, interface)).to eq("\n\n# Title\n\n")
    end

    it "renders an h6 with six # prefixes" do
      element = Markbridge::AST::Heading.new(level: 6)
      element << Markbridge::AST::Text.new("Title")

      expect(tag.render(element, interface)).to eq("\n\n###### Title\n\n")
    end

    it "renders an h3 with exactly three # prefixes" do
      element = Markbridge::AST::Heading.new(level: 3)
      element << Markbridge::AST::Text.new("Title")

      expect(tag.render(element, interface)).to eq("\n\n### Title\n\n")
    end

    let(:element_class) { Markbridge::AST::Heading }
    let(:element_factory) { Markbridge::AST::Heading.new(level: 2) }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <h{level}>" do
        element = Markbridge::AST::Heading.new(level: 3)
        element << Markbridge::AST::Text.new("Title")

        expect(tag.render(element, interface)).to eq("<h3>Title</h3>")
      end

      it "clamps levels above 6" do
        element = Markbridge::AST::Heading.new(level: 9)
        element << Markbridge::AST::Text.new("X")

        expect(tag.render(element, interface)).to eq("<h6>X</h6>")
      end

      it "clamps levels below 1" do
        element = Markbridge::AST::Heading.new(level: 0)
        element << Markbridge::AST::Text.new("X")

        expect(tag.render(element, interface)).to eq("<h1>X</h1>")
      end
    end
  end
end
