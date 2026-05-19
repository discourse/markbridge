# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::DetailsTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders [details=\"title\"]…[/details] bracketed by blank lines" do
      element = Markbridge::AST::Details.new(title: "Show more")
      element << Markbridge::AST::Text.new("hidden body")

      expect(tag.render(element, interface)).to eq(
        %(\n\n[details="Show more"]\nhidden body\n[/details]\n\n),
      )
    end

    it "omits the =\"…\" when no title is set, producing bare [details]" do
      element = Markbridge::AST::Details.new
      element << Markbridge::AST::Text.new("body")

      expect(tag.render(element, interface)).to eq("\n\n[details]\nbody\n[/details]\n\n")
    end

    it "strips leading/trailing whitespace inside the block" do
      # Block-level children frequently emit their own \n\n bracketing
      # (Quote, Table, …). Without stripping, the [details] opener
      # would be followed by a stray blank line and the BBCode parser
      # would treat the body as a separate paragraph.
      element = Markbridge::AST::Details.new(title: "X")
      element << Markbridge::AST::Text.new("\n\nbody with leading\n\n")

      expect(tag.render(element, interface)).to eq(
        %(\n\n[details="X"]\nbody with leading\n[/details]\n\n),
      )
    end

    it "renders nested children through the renderer" do
      element = Markbridge::AST::Details.new(title: "T")
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("inner")
      element << bold

      expect(tag.render(element, interface)).to eq(%(\n\n[details="T"]\n**inner**\n[/details]\n\n))
    end

    let(:element_class) { Markbridge::AST::Details }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <details><summary>title</summary>…</details>" do
        element = Markbridge::AST::Details.new(title: "Show more")
        element << Markbridge::AST::Text.new("body")

        expect(tag.render(element, interface)).to eq(
          "<details><summary>Show more</summary>body</details>",
        )
      end

      it "uses the default 'Summary' label when no title is set" do
        element = Markbridge::AST::Details.new
        element << Markbridge::AST::Text.new("body")

        expect(tag.render(element, interface)).to eq(
          "<details><summary>Summary</summary>body</details>",
        )
      end

      it "HTML-escapes the title" do
        element = Markbridge::AST::Details.new(title: %(<scary> & "stuff"))
        element << Markbridge::AST::Text.new("x")

        expect(tag.render(element, interface)).to eq(
          "<details><summary>&lt;scary&gt; &amp; &quot;stuff&quot;</summary>x</details>",
        )
      end
    end
  end

  describe "auto-registration" do
    it "is registered against AST::Details in the default TagLibrary" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default

      expect(library[Markbridge::AST::Details]).to be_a(described_class)
    end
  end
end
