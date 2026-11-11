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

    context "with a URL at the end of the content" do
      let(:url) { Markbridge::AST::Url.new(href: "https://e.com/a") }

      def spoiler_with(*children, **options)
        element = Markbridge::AST::Spoiler.new(**options)
        children.each { |child| element << child }
        element
      end

      # The closing tag would become part of the URL in front of it.
      it "writes a bare URL as a link and puts a comment after a URL in text" do
        expect(rendered(spoiler_with(Markbridge::AST::Text.new("see "), url))).to eq(
          "[spoiler]see [https://e.com/a](https://e.com/a)[/spoiler]",
        )
        expect(rendered(spoiler_with(Markbridge::AST::Text.new("https://e.com/a")))).to eq(
          "[spoiler]https://e.com/a<!---->[/spoiler]",
        )
      end

      it "leaves the URL bare where no closing tag follows it on the line" do
        block = spoiler_with(url, block: true)
        link = Markbridge::AST::Url.new(href: "https://example.com")

        expect(rendered(block)).to eq("\n\n[spoiler]\nhttps://e.com/a\n[/spoiler]\n\n")
        expect(rendered(spoiler_with(url), interface_for(link))).to eq("https://e.com/a")
        expect(described_class.new(bbcode: false).render(spoiler_with(url), interface)).to eq(
          "https://e.com/a",
        )
        expect(rendered(spoiler_with(url), interface_for(html_mode: true))).to eq(
          %(<span class="spoiler"><a href="https://e.com/a">https://e.com/a</a></span>),
        )
      end
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

      it "writes the comment also with text between the two" do
        second = spoiler("y")
        parent = paragraph_with(spoiler("x"), Markbridge::AST::Text.new(" and "), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]<!---->")
      end

      it "writes the comment also with an inline element between the two" do
        second = spoiler("y")
        bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("b")
        parent = paragraph_with(spoiler("x"), bold, second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]<!---->")
      end

      it "writes the comment when only whitespace follows the newline of the text between" do
        second = spoiler("y")
        parent = paragraph_with(spoiler("x"), Markbridge::AST::Text.new("a \n "), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]<!---->")
      end

      it "writes no comment when the text between starts the line of the second" do
        second = spoiler("y")
        parent = paragraph_with(spoiler("x"), Markbridge::AST::Text.new(" a\n b "), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]")
      end

      it "writes no comment after a spoiler with a title, which starts its line with the title" do
        second = spoiler("y")
        first = Markbridge::AST::Spoiler.new(title: "Reveal") << Markbridge::AST::Text.new("x")
        parent = paragraph_with(first, Markbridge::AST::Text.new(" "), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]")
      end

      it "looks over a spoiler with a title to the spoiler in front of it" do
        second = spoiler("y")
        titled = Markbridge::AST::Spoiler.new(title: "Reveal") << Markbridge::AST::Text.new("x")
        parent = paragraph_with(spoiler("w"), Markbridge::AST::Text.new(" "), titled, second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]<!---->")
      end

      it "writes no comment after the first spoiler" do
        first = spoiler("x")
        parent = paragraph_with(first, spoiler("y"))

        expect(tag.render(first, interface_for(parent))).to eq("[spoiler]x[/spoiler]")
      end

      it "writes no comment when whitespace follows something else than a spoiler" do
        second = spoiler("y")
        bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("b")
        parent = paragraph_with(bold, Markbridge::AST::Text.new(" "), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]")
      end

      it "writes the comment with an empty text between the two" do
        second = spoiler("y")
        parent = paragraph_with(spoiler("x"), Markbridge::AST::Text.new(""), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]<!---->")
      end

      it "counts a subclass of Text that starts the line like the class" do
        text_class = Class.new(Markbridge::AST::Text)
        second = spoiler("y")
        parent = paragraph_with(spoiler("x"), text_class.new(" a\n b "), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]")
      end

      it "counts subclasses of Spoiler and Text like the classes" do
        spoiler_class = Class.new(Markbridge::AST::Spoiler)
        text_class = Class.new(Markbridge::AST::Text)
        second = spoiler("y")
        first = spoiler_class.new << Markbridge::AST::Text.new("x")
        parent = paragraph_with(first, text_class.new(" "), second)

        expect(tag.render(second, interface_for(parent))).to eq("[spoiler]y[/spoiler]<!---->")
      end
    end

    it "writes only the content inside a link, where Discourse cooks no BBCode" do
      element = Markbridge::AST::Spoiler.new(title: "Reveal")
      element << Markbridge::AST::Text.new("hidden")
      link = Markbridge::AST::Url.new(href: "https://example.com")

      expect(tag.render(element, interface_for(link))).to eq("Reveal: hidden")
      expect(tag.render(element, interface_for(link, html_mode: true))).to eq("Reveal: hidden")
    end

    it "writes only the content inside an email link" do
      element = Markbridge::AST::Spoiler.new
      element << Markbridge::AST::Text.new("hidden")
      email = Markbridge::AST::Email.new(address: "a@example.com")

      expect(tag.render(element, interface_for(email))).to eq("hidden")
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

    context "with a block spoiler" do
      def block_spoiler(content, title: nil)
        Markbridge::AST::Spoiler.new(title:, block: true) << Markbridge::AST::Text.new(content)
      end

      it "writes the tags on lines of their own, as a block" do
        expect(tag.render(block_spoiler("hidden"), interface)).to eq(
          "\n\n[spoiler]\nhidden\n[/spoiler]\n\n",
        )
      end

      it "has no blank lines at the start and the end of the content" do
        expect(tag.render(block_spoiler("\n\na\n\nb\n\n"), interface)).to eq(
          "\n\n[spoiler]\na\n\nb\n[/spoiler]\n\n",
        )
      end

      it "writes the title as a paragraph in front, without the space after the colon" do
        expect(tag.render(block_spoiler("hidden", title: " *Season 3* "), interface)).to eq(
          "\n\n\\*Season 3\\*:\n\n[spoiler]\nhidden\n[/spoiler]\n\n",
        )
      end

      it "leaves a colon at the start of the content alone, the tag has a line of its own" do
        expect(tag.render(block_spoiler(":x"), interface)).to eq(
          "\n\n[spoiler]\n:x\n[/spoiler]\n\n",
        )
      end

      it "writes no comment after a spoiler in front, it is not on its line" do
        second = block_spoiler("y")
        parent = Markbridge::AST::Document.new << block_spoiler("x") << second

        expect(tag.render(second, interface_for(parent))).to eq("\n\n[spoiler]\ny\n[/spoiler]\n\n")
      end

      it "renders an empty one to nothing" do
        expect(tag.render(Markbridge::AST::Spoiler.new(title: "T", block: true), interface)).to eq(
          "",
        )
      end

      it "writes the content like an inline spoiler inside a link" do
        link = Markbridge::AST::Url.new(href: "https://example.com")
        email = Markbridge::AST::Email.new(address: "a@example.com")

        expect(tag.render(block_spoiler("hidden", title: "T"), interface_for(link))).to eq(
          "T: hidden",
        )
        expect(tag.render(block_spoiler("hidden"), interface_for(email))).to eq("hidden")
      end

      it "writes a div in html_mode, with the title in front" do
        interface = interface_for(html_mode: true)

        expect(tag.render(block_spoiler("hidden"), interface)).to eq(
          %(<div class="spoiler">hidden</div>),
        )
        expect(tag.render(block_spoiler("hidden", title: "A & B"), interface)).to eq(
          %(A &amp; B:<div class="spoiler">hidden</div>),
        )
      end

      it "writes a div without the class in html_mode without the plugin" do
        tag = described_class.new(bbcode: false)
        interface = interface_for(html_mode: true)

        expect(tag.render(block_spoiler("hidden"), interface)).to eq("<div>hidden</div>")
        expect(tag.render(block_spoiler("hidden", title: "T"), interface)).to eq(
          "T:<div>hidden</div>",
        )
      end

      it "writes the content as a block of its own without the plugin" do
        tag = described_class.new(bbcode: false)

        expect(tag.render(block_spoiler("\nhidden\n"), interface)).to eq("\n\nhidden\n\n")
        expect(tag.render(block_spoiler("hidden", title: "T"), interface)).to eq(
          "\n\nT:\n\nhidden\n\n",
        )
      end
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
