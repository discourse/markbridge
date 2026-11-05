# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::SpoilerTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "wraps content in [spoiler]...[/spoiler] when no title is set" do
      element = Markbridge::AST::Spoiler.new
      element << Markbridge::AST::Text.new("hidden")

      expect(tag.render(element, interface)).to eq("[spoiler]hidden[/spoiler]")
    end

    it "escapes a colon at the start of the content" do
      element = Markbridge::AST::Spoiler.new
      element << Markbridge::AST::Text.new(":x")

      expect(tag.render(element, interface)).to eq("[spoiler]\\:x[/spoiler]")
    end

    it "renders an empty element to nothing" do
      element = Markbridge::AST::Spoiler.new(title: "Click me")

      expect(tag.render(element, interface)).to eq("")
    end

    it "uses [spoiler=title] form when a title is set" do
      element = Markbridge::AST::Spoiler.new(title: "Click me")
      element << Markbridge::AST::Text.new("hidden")

      expect(tag.render(element, interface)).to eq("[spoiler=Click me]hidden[/spoiler]")
    end

    let(:element_class) { Markbridge::AST::Spoiler }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { html_context }

      it "renders the span Discourse cooks the BBCode to" do
        element = Markbridge::AST::Spoiler.new
        element << Markbridge::AST::Text.new("hidden")

        expect(tag.render(element, interface)).to eq(%(<span class="spoiler">hidden</span>))
      end

      it "has no place for the title" do
        element = Markbridge::AST::Spoiler.new(title: "Reveal")
        element << Markbridge::AST::Text.new("hidden")

        expect(tag.render(element, interface)).to eq(%(<span class="spoiler">hidden</span>))
      end

      it "writes no span around nothing visible" do
        element = Markbridge::AST::Spoiler.new
        element << Markbridge::AST::Text.new(" \n")

        expect(tag.render(element, interface)).to eq(" \n")
      end
    end
  end
end
