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

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <details> with default summary" do
        element = Markbridge::AST::Spoiler.new
        element << Markbridge::AST::Text.new("hidden")

        expect(tag.render(element, interface)).to eq(
          "<details><summary>Spoiler</summary>hidden</details>",
        )
      end

      it "uses the title as <summary> when present" do
        element = Markbridge::AST::Spoiler.new(title: "Reveal")
        element << Markbridge::AST::Text.new("hidden")

        expect(tag.render(element, interface)).to eq(
          "<details><summary>Reveal</summary>hidden</details>",
        )
      end

      it "HTML-escapes the title" do
        element = Markbridge::AST::Spoiler.new(title: %(<scary> & "stuff"))
        element << Markbridge::AST::Text.new("x")

        expect(tag.render(element, interface)).to eq(
          "<details><summary>&lt;scary&gt; &amp; &quot;stuff&quot;</summary>x</details>",
        )
      end
    end
  end
end
