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

    # A line that starts with [spoiler] and ends with [/spoiler] is one block
    # spoiler to Discourse, so a second spoiler on it needs something after it.
    context "when a spoiler stands in front" do
      def paragraph_with(*nodes)
        paragraph = Markbridge::AST::Paragraph.new
        nodes.each { |node| paragraph << node }
        paragraph
      end

      def spoiler(text)
        Markbridge::AST::Spoiler.new << Markbridge::AST::Text.new(text)
      end

      it "writes a comment after the second spoiler" do
        second = spoiler("y")
        paragraph_with(spoiler("x"), second)

        expect(tag.render(second, interface_for(paragraph_with(spoiler("x"), second)))).to eq(
          "[spoiler]y[/spoiler]<!---->",
        )
      end

      it "writes the comment also with whitespace between the two" do
        second = spoiler("y")
        parent = paragraph_with(spoiler("x"), Markbridge::AST::Text.new(" \n"), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]<!---->")
      end

      it "writes no comment after text between the two" do
        second = spoiler("y")
        parent = paragraph_with(spoiler("x"), Markbridge::AST::Text.new(" a "), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]")
      end

      it "writes no comment after the first spoiler" do
        first = spoiler("x")
        parent = paragraph_with(first, spoiler("y"))

        expect(tag.render(first, interface_for(parent))).to eq("[spoiler]x[/spoiler]")
      end
    end

    it "writes only the content inside a link, where Discourse cooks no BBCode" do
      element = Markbridge::AST::Spoiler.new(title: "Reveal")
      element << Markbridge::AST::Text.new("hidden")
      link = Markbridge::AST::Url.new(href: "https://example.com")

      expect(tag.render(element, interface_for(link))).to eq("Reveal: hidden")
      expect(tag.render(element, interface_for(link, html_mode: true))).to eq("Reveal: hidden")
    end

    it "writes the title as text in front of the spoiler" do
      element = Markbridge::AST::Spoiler.new(title: "Click me")
      element << Markbridge::AST::Text.new("hidden")

      expect(tag.render(element, interface)).to eq("Click me: [spoiler]hidden[/spoiler]")
    end

    it "escapes the title like any text" do
      element = Markbridge::AST::Spoiler.new(title: " *Season 3* ")
      element << Markbridge::AST::Text.new("hidden")

      expect(tag.render(element, interface)).to eq("\\*Season 3\\*: [spoiler]hidden[/spoiler]")
    end

    it "ignores a title that is only whitespace" do
      element = Markbridge::AST::Spoiler.new(title: " \n")
      element << Markbridge::AST::Text.new("hidden")

      expect(tag.render(element, interface)).to eq("[spoiler]hidden[/spoiler]")
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

      it "writes the title as escaped text in front of the span" do
        element = Markbridge::AST::Spoiler.new(title: "A & B")
        element << Markbridge::AST::Text.new("hidden")

        expect(tag.render(element, interface)).to eq(
          %(A &amp; B: <span class="spoiler">hidden</span>),
        )
      end

      it "writes no span around nothing visible" do
        element = Markbridge::AST::Spoiler.new
        element << Markbridge::AST::Text.new(" \n")

        expect(tag.render(element, interface)).to eq(" \n")
      end
    end

    context "with bbcode: false" do
      let(:tag) { described_class.new(bbcode: false) }

      it "writes the content as it is" do
        element = Markbridge::AST::Spoiler.new
        element << Markbridge::AST::Text.new(":hidden")

        expect(tag.render(element, interface)).to eq(":hidden")
      end

      it "keeps the title in front" do
        element = Markbridge::AST::Spoiler.new(title: "Reveal")
        element << Markbridge::AST::Text.new("hidden")

        expect(tag.render(element, interface)).to eq("Reveal: hidden")
      end

      it "writes the content as it is in html_mode" do
        element = Markbridge::AST::Spoiler.new(title: "Reveal")
        element << Markbridge::AST::Text.new("hidden")

        expect(tag.render(element, interface_for(html_mode: true))).to eq("Reveal: hidden")
      end
    end
  end
end
