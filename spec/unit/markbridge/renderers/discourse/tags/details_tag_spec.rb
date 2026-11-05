# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::DetailsTag do
  include_context "with a renderer tag"

  describe "#render" do
    it "renders [details=\"title\"]…[/details] with blank lines around the tags and the body" do
      element = Markbridge::AST::Details.new(title: "Show more")
      element << Markbridge::AST::Text.new("hidden body")

      expect(tag.render(element, interface)).to eq(
        %(\n\n[details="Show more"]\n\nhidden body\n\n[/details]\n\n),
      )
    end

    it "strips whitespace on both sides of the body" do
      element = Markbridge::AST::Details.new(title: "Show more")
      element << Markbridge::AST::Text.new(" \nhidden body\n ")

      expect(tag.render(element, interface)).to eq(
        %(\n\n[details="Show more"]\n\nhidden body\n\n[/details]\n\n),
      )
    end

    it "renders an element with no content to nothing" do
      element = Markbridge::AST::Details.new(title: "Empty")

      expect(tag.render(element, interface)).to eq("")
    end

    it "renders whitespace-only content to nothing" do
      element = Markbridge::AST::Details.new(title: "Empty")
      element << Markbridge::AST::Text.new(" \n ")

      expect(tag.render(element, interface)).to eq("")
    end

    it "omits the =\"…\" when no title is set, producing bare [details]" do
      element = Markbridge::AST::Details.new
      element << Markbridge::AST::Text.new("body")

      expect(tag.render(element, interface)).to eq("\n\n[details]\n\nbody\n\n[/details]\n\n")
    end

    it "strips leading/trailing whitespace inside the block" do
      # Block-level children emit their own \n\n bracketing (Quote,
      # Table, …), and the tag puts exactly one blank line on each side.
      element = Markbridge::AST::Details.new(title: "X")
      element << Markbridge::AST::Text.new("\n\nbody with leading\n\n")

      expect(tag.render(element, interface)).to eq(
        %(\n\n[details="X"]\n\nbody with leading\n\n[/details]\n\n),
      )
    end

    it "renders nested children through the renderer" do
      element = Markbridge::AST::Details.new(title: "T")
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("inner")
      element << bold

      expect(tag.render(element, interface)).to eq(
        %(\n\n[details="T"]\n\n**inner**\n\n[/details]\n\n),
      )
    end

    let(:element_class) { Markbridge::AST::Details }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { html_context }

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

  context "with bbcode: false" do
    let(:tag) { described_class.new(bbcode: false) }

    it "writes the title as a paragraph in bold in front of the content" do
      element = Markbridge::AST::Details.new(title: "Show more")
      element << Markbridge::AST::Text.new("hidden body")

      expect(tag.render(element, interface)).to eq("\n\n**Show more**\n\nhidden body\n\n")
    end

    it "escapes the title like any text" do
      element = Markbridge::AST::Details.new(title: " *x* ")
      element << Markbridge::AST::Text.new("body")

      expect(tag.render(element, interface)).to eq("\n\n**\\*x\\***\n\nbody\n\n")
    end

    it "writes only the content without a title" do
      element = Markbridge::AST::Details.new(title: " ")
      element << Markbridge::AST::Text.new("body")

      expect(tag.render(element, interface)).to eq("\n\nbody\n\n")
    end

    it "renders an element with no content to nothing" do
      element = Markbridge::AST::Details.new(title: "Empty")

      expect(tag.render(element, interface)).to eq("")
    end

    context "in html_mode" do
      let(:context) { html_context }

      it "writes the title as a paragraph in bold, HTML-escaped and without edge whitespace" do
        element = Markbridge::AST::Details.new(title: " A & B ")
        element << Markbridge::AST::Text.new("body")

        expect(tag.render(element, interface)).to eq("<p><strong>A &amp; B</strong></p>body")
      end

      it "writes only the content without a title" do
        element = Markbridge::AST::Details.new
        element << Markbridge::AST::Text.new("body")

        expect(tag.render(element, interface)).to eq("body")
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
