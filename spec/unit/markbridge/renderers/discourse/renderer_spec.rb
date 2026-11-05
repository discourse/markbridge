# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Renderer do
  let(:renderer) { described_class.new }

  describe "#initialize" do
    it "uses an explicit tag_library when one is provided" do
      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new { |_e, _i| "BOLD" },
      )

      result = described_class.new(tag_library: library).render(Markbridge::AST::Bold.new)

      expect(result).to eq("BOLD")
    end

    it "uses an explicit escaper when one is provided" do
      escaper = instance_double(Markbridge::Renderers::Discourse::MarkdownEscaper)
      allow(escaper).to receive(:escape).and_return("ESCAPED")

      result = described_class.new(escaper:).render(Markbridge::AST::Text.new("hi"))

      expect(result).to eq("ESCAPED")
      expect(escaper).to have_received(:escape).with("hi", in_link_label: false)
    end

    it "falls back to TagLibrary.default when no tag_library is provided" do
      result =
        described_class.new.render(
          Markbridge::AST::Bold.new.tap { |b| b << Markbridge::AST::Text.new("x") },
        )

      expect(result).to eq("**x**")
    end

    it "falls back to MarkdownEscaper.new when no escaper is provided" do
      # The default escaper must escape Markdown-significant characters in plain text.
      result = described_class.new.render(Markbridge::AST::Text.new("a*b"))

      expect(result).to eq('a\*b')
    end

    it "falls back to Postprocessor::DEFAULT when no postprocessor is provided" do
      expect(described_class.new.postprocessor).to be(
        Markbridge::Renderers::Discourse::Postprocessor::DEFAULT,
      )
    end

    it "uses an explicit postprocessor when one is provided" do
      custom = Markbridge::Renderers::Discourse::Postprocessor.new

      expect(described_class.new(postprocessor: custom).postprocessor).to be(custom)
    end

    it "uses an explicit html_escaper when one is provided" do
      html_escaper = class_double(Markbridge::Renderers::Discourse::HtmlEscaper)
      allow(html_escaper).to receive(:escape).and_return("HTML-ESCAPED")

      text = Markbridge::AST::Text.new("a < b")
      context = Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true)
      renderer = described_class.new(html_escaper:)

      expect(renderer.render(text, context:)).to eq("HTML-ESCAPED")
      expect(html_escaper).to have_received(:escape).with("a < b")
      # The serializer gets it too, for the attributes it writes.
      expect(renderer.render(Markbridge::AST::Image.new(src: "a&b.png"), context:)).to eq(
        %(<img src="HTML-ESCAPED" alt="HTML-ESCAPED">),
      )
    end

    it "falls back to the HtmlEscaper class when no html_escaper is provided" do
      # The default html_escaper must HTML-escape `<` and `&` in html_mode.
      text = Markbridge::AST::Text.new("a < b & c")
      context = Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true)
      result = described_class.new.render(text, context:)

      expect(result).to eq("a &lt; b &amp; c")
    end
  end

  describe "#render" do
    it "is at no child outside render_children" do
      expect(renderer.current_child?(Markbridge::AST::Text.new("x"))).to be(false)
    end

    it "is at no child when the reported position is past the end" do
      parent = Markbridge::AST::Paragraph.new << Markbridge::AST::Text.new("x")
      allow(renderer).to receive_messages(child_parent: parent, child_index: 3)

      expect(renderer.current_child?(parent.children.first)).to be(false)
    end

    it "renders text in a context that has an element but no enclosing context" do
      context =
        Markbridge::Renderers::Discourse::RenderContext.new(element: Markbridge::AST::Bold.new)

      expect(renderer.render(Markbridge::AST::Text.new("*hi*"), context:)).to eq("\\*hi\\*")
    end

    it "renders a document by rendering its children" do
      document = Markbridge::AST::Document.new
      text = Markbridge::AST::Text.new("hello")
      document << text

      result = renderer.render(document)
      expect(result).to eq("hello")
    end

    it "gives the children of an element without a tag their siblings through the root" do
      # The Document has no tag and does not go on the parent chain, but
      # its children can still ask for their siblings: the bare URL sees
      # the text in front of it.
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("see")
      url = Markbridge::AST::Url.new(href: "https://example.com")
      url << Markbridge::AST::Text.new("https://example.com")
      document << url

      expect(renderer.render(document)).to eq("see[https://example.com](https://example.com)")
    end

    it "keeps an element without a tag off the parent chain" do
      probe = nil
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new do |_element, interface|
          probe = interface.context
          ""
        end,
      )
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Bold.new
      described_class.new(tag_library: library).render(document)

      expect(probe.parents).to eq([])
      expect(probe.root).to be(document)
    end

    it "sets the root also for an element without a tag below the top" do
      probe = nil
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new do |_element, interface|
          probe = interface.context
          ""
        end,
      )
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Bold.new
      context = Markbridge::Renderers::Discourse::RenderContext.new([Markbridge::AST::Italic.new])
      described_class.new(tag_library: library).render(document, context:)

      expect(probe.root).to be(document)
    end

    it "does not replace a root that is already set" do
      probe = nil
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new do |_element, interface|
          probe = interface.context
          ""
        end,
      )
      outer = Markbridge::AST::Document.new
      inner = Markbridge::AST::Document.new
      inner << Markbridge::AST::Bold.new
      outer << inner
      described_class.new(tag_library: library).render(outer)

      expect(probe.root).to be(outer)
    end

    it "renders text nodes" do
      text = Markbridge::AST::Text.new("hello world")
      result = renderer.render(text)
      expect(result).to eq("hello world")
    end

    it "returns empty string for unknown node types" do
      unknown = Object.new
      result = renderer.render(unknown)
      expect(result).to eq("")
    end

    it "passes Text content through verbatim inside Code in Markdown mode (no HTML escaping)" do
      # `a < b` would change under html-escape (`a &lt; b`) but not under
      # markdown-escape — locks in that the Code-parent path returns node.text.
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("a < b")
      context = Markbridge::Renderers::Discourse::RenderContext.new([code])

      expect(renderer.render(code.children.first, context:)).to eq("a < b")
    end

    it "escapes Text content when no ancestor is Code" do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("a*b")

      expect(renderer.render(bold)).to eq("**a\\*b**")
    end

    it "escapes ] in Text content when an ancestor is Url (link-label context)" do
      url = Markbridge::AST::Url.new(href: "https://example.com")
      url << Markbridge::AST::Text.new("[A]")

      expect(renderer.render(url)).to eq("[\\[A\\]](https://example.com)")
    end

    it "escapes ] in Text content under a link, a mail link, an image, an upload and their subclasses" do
      parents = [
        [Markbridge::AST::Url, { href: "https://example.com" }],
        [Markbridge::AST::Email, { address: "alice@example.com" }],
        [Markbridge::AST::Image, { src: "x.png" }],
        [Markbridge::AST::Upload, { sha1: "abc", type: :image }],
      ]

      parents.each do |base, arguments|
        [base, Class.new(base)].each do |link_class|
          context =
            Markbridge::Renderers::Discourse::RenderContext.new([link_class.new(**arguments)])

          expect(renderer.render(Markbridge::AST::Text.new("[A]"), context:)).to eq("\\[A\\]")
        end
      end
    end

    it "does not escape ] in Text content under a parent that is no link" do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("a]b")

      expect(renderer.render(bold)).to eq("**a]b**")
    end

    it "escapes ] in Text content when the link is further up the chain" do
      url = Markbridge::AST::Url.new(href: "https://example.com")
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("[A]")
      url << bold

      expect(renderer.render(url)).to eq("[**\\[A\\]**](https://example.com)")
    end

    it "keeps Text verbatim under a subclass of Code" do
      code = Class.new(Markbridge::AST::Code).new
      context = Markbridge::Renderers::Discourse::RenderContext.new([code])

      expect(renderer.render(Markbridge::AST::Text.new("a*b"), context:)).to eq("a*b")
    end

    it "keeps Text verbatim when the Code is further up the chain" do
      code = Markbridge::AST::Code.new
      bold = Markbridge::AST::Bold.new
      context = Markbridge::Renderers::Discourse::RenderContext.new([code, bold])

      expect(renderer.render(Markbridge::AST::Text.new("a*b"), context:)).to eq("a*b")
    end

    it "does not escape ] in Text content when no link ancestor is present" do
      text = Markbridge::AST::Text.new("plain ] text")

      expect(renderer.render(text)).to eq("plain ] text")
    end

    context "with AST subclasses" do
      let(:subclass) { Class.new(Markbridge::AST::Bold) }

      it "renders a subclass without its own tag through the base class tag" do
        node = subclass.new << Markbridge::AST::Text.new("text")

        expect(renderer.render(node)).to eq("**text**")
      end

      it "renders an anonymous subclass like its base class (intentional)" do
        # Ancestry dispatch applies to anonymous classes too — there is
        # nothing special about a missing name.
        node = Class.new(Markbridge::AST::Italic).new << Markbridge::AST::Text.new("text")

        expect(renderer.render(node)).to eq("*text*")
      end

      it "works with the frozen shared_default library" do
        node = subclass.new << Markbridge::AST::Text.new("text")
        shared =
          described_class.new(
            tag_library: Markbridge::Renderers::Discourse::TagLibrary.shared_default,
          )

        expect(shared.render(node)).to eq("**text**")
      end

      it "prefers the subclass's own tag over the inherited one" do
        library = Markbridge::Renderers::Discourse::TagLibrary.default
        library.register(subclass, Markbridge::Renderers::Discourse::Tag.new { |_, _| "OWN" })
        node = subclass.new << Markbridge::AST::Text.new("text")

        expect(described_class.new(tag_library: library).render(node)).to eq("OWN")
      end

      it "restores plain child rendering when Tag::PASSTHROUGH is registered" do
        library = Markbridge::Renderers::Discourse::TagLibrary.default
        library.register(subclass, Markbridge::Renderers::Discourse::Tag::PASSTHROUGH)
        node = subclass.new << Markbridge::AST::Text.new("text")

        expect(described_class.new(tag_library: library).render(node)).to eq("text")
      end

      it "asks the library to resolve each class once per render call, caching nil results" do
        library = instance_double(Markbridge::Renderers::Discourse::TagLibrary)
        allow(library).to receive(:[]).and_return(nil)
        allow(library).to receive(:resolve).and_return(nil)
        renderer = described_class.new(tag_library: library)
        document = Markbridge::AST::Document.new
        # Two elements of the same class (Text would auto-merge).
        document << Markbridge::AST::Bold.new << Markbridge::AST::Bold.new

        renderer.render(document)

        # Two Bold nodes, one ancestry walk: the per-call cache stores the
        # nil result instead of walking again.
        expect(library).to have_received(:resolve).with(Markbridge::AST::Bold).once
        expect(library).to have_received(:resolve).with(Markbridge::AST::Document).once
      end
    end

    context "in html_mode" do
      it "HTML-escapes text" do
        text = Markbridge::AST::Text.new("a < b")
        context = Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true)

        expect(renderer.render(text, context:)).to eq("a &lt; b")
      end

      it "HTML-escapes text inside AST::Code" do
        code = Markbridge::AST::Code.new
        code << Markbridge::AST::Text.new("a < b")
        context = Markbridge::Renderers::Discourse::RenderContext.new([code], html_mode: true)

        expect(renderer.render(code.children.first, context:)).to eq("a &lt; b")
      end
    end

    context "when dispatching to a tag in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "splices the tag's output verbatim, with no extra wrapping" do
        bold = Markbridge::AST::Bold.new
        bold << Markbridge::AST::Text.new("hi")

        expect(renderer.render(bold, context:)).to eq("<strong>hi</strong>")
      end
    end

    context "when rendering MarkdownText nodes" do
      it "passes through verbatim in Markdown mode" do
        node = Markbridge::AST::MarkdownText.new("**already bold**")
        result = renderer.render(node)
        expect(result).to eq("**already bold**")
      end

      it "wraps in blank lines in html_mode so CommonMark re-enters Markdown parsing" do
        node = Markbridge::AST::MarkdownText.new("**already bold**")
        context = Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true)

        result = renderer.render(node, context:)
        expect(result).to eq("\n\n**already bold**\n\n")
      end
    end
  end

  describe "#render_tokens" do
    it "returns the children's output as tokens, finished Markdown as it is" do
      tokens = Markbridge::Renderers::Discourse::Inline::Tokens
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("a") <<
        Markbridge::AST::Bold.new.<<(Markbridge::AST::Text.new("b"))
      document << Markbridge::AST::Bold.new

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_tokens(document, context:)).to eq(
        [
          "a",
          tokens.open(:strong),
          "b",
          tokens.close(:strong),
          tokens.open(:strong),
          tokens.close(:strong),
        ],
      )
    end

    it "forgets the resolved tags after a top-level call" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      renderer_with_library = described_class.new(tag_library: library)
      bold_class = Class.new(Markbridge::AST::Bold)
      element = bold_class.new << Markbridge::AST::Text.new("a")
      context = Markbridge::Renderers::Discourse::RenderContext.new

      # Resolved through its ancestry to the Bold tag, and remembered for
      # this call only: a tag registered for the ancestor afterwards is
      # found by the next call.
      renderer_with_library.render_tokens(Markbridge::AST::Document.new([element]), context:)
      library.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new { |_, _| "custom" },
      )

      expect(renderer_with_library.render(Markbridge::AST::Document.new([element]))).to eq("custom")
    end
  end

  describe "#render with tags that return tokens" do
    it "renders a wrapper after a nested wrapper" do
      # The nested call must not take the interface cache of the outer
      # call with it when it ends.
      inner = Markbridge::AST::Italic.new << Markbridge::AST::Text.new("a")
      bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("b")
      document = Markbridge::AST::Document.new([Markbridge::AST::Italic.new << inner << bold])

      expect(renderer.render(document)).to eq("<em>*a*<!---->**b**</em>")
    end

    it "starts the list bookkeeping afresh for the children of a wrapper" do
      # A list inside a wrapper that returns tokens does not see the
      # list in front of the wrapper, so it gets no separator.
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      wrapper_class = Class.new(Markbridge::AST::Element)
      library.register(
        wrapper_class,
        Markbridge::Renderers::Discourse::Tag.new do |element, interface|
          interface.render_tokens(element)
        end,
      )
      list = ->(text) do
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new(text)
        )
      end
      document =
        Markbridge::AST::Document.new([list.call("a"), wrapper_class.new << list.call("b")])

      expect(described_class.new(tag_library: library).render(document)).not_to include("<!---->")
    end

    it "knows the parent of the children it renders, also one that is not on the chain" do
      # A tag that asks for its siblings while its parent did not put
      # itself on the chain: the renderer still knows the parent.
      seen = nil
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      parent_class = Class.new(Markbridge::AST::Element)
      child_class = Class.new(Markbridge::AST::Element)
      library.register(
        parent_class,
        Markbridge::Renderers::Discourse::Tag.new do |element, interface|
          interface.render_tokens(element)
        end,
      )
      library.register(
        child_class,
        Markbridge::Renderers::Discourse::Tag.new do |element, interface|
          seen = interface.previous_sibling(element)
          "x"
        end,
      )
      first = Markbridge::AST::Text.new("a")
      parent = parent_class.new << first << child_class.new
      document = Markbridge::AST::Document.new << Markbridge::AST::Text.new("b") << parent

      described_class.new(tag_library: library).render(document)

      expect(seen).to be(first)
    end

    it "knows the position of the child it renders, also after a nested call" do
      positions = []
      renderer_with_tag = nil
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(
        Markbridge::AST::Italic,
        Markbridge::Renderers::Discourse::Tag.new do |element, interface|
          tokens = interface.render_tokens(element, context: interface.with_parent(element))
          positions << renderer_with_tag.child_index
          tokens
        end,
      )
      renderer_with_tag = described_class.new(tag_library: library)
      document = Markbridge::AST::Document.new
      inner = Markbridge::AST::Italic.new << Markbridge::AST::Text.new("a")
      outer = Markbridge::AST::Italic.new << Markbridge::AST::Text.new("b") << inner
      document << Markbridge::AST::Text.new("c") << outer

      expect(renderer_with_tag.render(document)).to eq("cba")
      expect(positions).to eq([1, 1])
      expect(renderer_with_tag.child_index).to be_nil
    end
  end

  describe "#render_children" do
    it "forgets the resolved tags after a top-level call" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      renderer_with_library = described_class.new(tag_library: library)
      bold_class = Class.new(Markbridge::AST::Bold)
      element = bold_class.new << Markbridge::AST::Text.new("a")
      context = Markbridge::Renderers::Discourse::RenderContext.new

      renderer_with_library.render_children(Markbridge::AST::Document.new([element]), context:)
      library.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new { |_, _| "custom" },
      )

      expect(renderer_with_library.render(Markbridge::AST::Document.new([element]))).to eq("custom")
    end

    it "forgets the lists of the outer level in a nested level with an edge of its own" do
      outer =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        )
      inner =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("b")
        )
      wrapper = Markbridge::AST::Quote.new << inner
      document = Markbridge::AST::Document.new << outer << wrapper

      # The quote line in front keeps the lists apart, the inner list
      # keeps the first marker.
      expect(renderer.render(document)).to include("> - b")
    end

    it "knows no previous list for a list that a tag renders on its own" do
      # The list is not the child that render_children is at, the state
      # of that level is not about it.
      first =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        )
      second =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("b")
        )
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new do |_element, interface|
          interface.render_node(second)
        end,
      )
      document = Markbridge::AST::Document.new << first << Markbridge::AST::Bold.new

      expect(described_class.new(tag_library: library).render(document)).not_to include("<!---->")
    end

    it "knows the position of the child it renders, also after a nested call" do
      positions = []
      renderer_with_tag = nil
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new do |element, interface|
          content = interface.render_children(element, context: interface.with_parent(element))
          positions << renderer_with_tag.child_index
          content
        end,
      )
      renderer_with_tag = described_class.new(tag_library: library)
      document = Markbridge::AST::Document.new
      inner = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("a")
      outer = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("b") << inner
      document << Markbridge::AST::Text.new("c") << outer

      renderer_with_tag.render(document)

      expect(positions).to eq([1, 1])
      expect(renderer_with_tag.child_index).to be_nil
    end

    it "renders all children" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("hello ")
      document << Markbridge::AST::Text.new("world")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)
      expect(result).to eq("hello world")
    end

    it "handles empty children" do
      document = Markbridge::AST::Document.new
      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)
      expect(result).to eq("")
    end

    # Each Text node is escaped on its own, so the escaper never sees the
    # paragraph line in front of the `=` line. Discourse would cook the
    # unescaped output as an <h1>.
    it "escapes a =-only text node that follows a line break" do
      paragraph = Markbridge::AST::Paragraph.new
      paragraph << Markbridge::AST::Text.new("Body")
      paragraph << Markbridge::AST::LineBreak.new
      paragraph << Markbridge::AST::Text.new("========")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(paragraph, context:)

      expect(result).to eq("Body\n\\=\\=\\=\\=\\=\\=\\=\\=")
    end

    it "forwards the context to each child render call" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("a*b")
      # Context with Code parent suppresses Text escaping; without forwarding it,
      # the child render would default to a fresh context and escape the *.
      code = Markbridge::AST::Code.new
      context = Markbridge::Renderers::Discourse::RenderContext.new.with_parent(code)

      expect(renderer.render_children(document, context:)).to eq("a*b")
    end

    it "yields the buffer and the child before appending the child's output" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("a")
      document << Markbridge::AST::MarkdownText.new("b")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      seen = []
      result =
        renderer.render_children(document, context:) { |buffer, child| seen << [buffer.dup, child] }

      expect(seen).to eq([["", document.children[0]], ["a", document.children[1]]])
      expect(result).to eq("ab")
    end
  end

  describe "#render with a misbehaving custom tag" do
    it "raises a TypeError when a tag returns neither a String nor tokens" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(Markbridge::AST::Bold, Markbridge::Renderers::Discourse::Tag.new { nil })
      renderer = described_class.new(tag_library: library)
      bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x")

      expect { renderer.render(bold) }.to raise_error(
        TypeError,
        /must return a String or inline tokens/,
      )
    end

    it "raises a TypeError when a tag returns something else that is truthy" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(Markbridge::AST::Bold, Markbridge::Renderers::Discourse::Tag.new { 42 })
      renderer = described_class.new(tag_library: library)

      expect { renderer.render(Markbridge::AST::Bold.new) }.to raise_error(TypeError, /42/)
    end

    it "names the offending node class in the error" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(Markbridge::AST::Bold, Markbridge::Renderers::Discourse::Tag.new { nil })
      renderer = described_class.new(tag_library: library)
      bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x")

      expect { renderer.render(bold) }.to raise_error(TypeError, /Bold/)
    end
  end

  describe "#render_default" do
    def renderer_with_bold_override(&block)
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(Markbridge::AST::Bold, Markbridge::Renderers::Discourse::Tag.new(&block))
      described_class.new(tag_library: library)
    end

    it "renders with the stock tag, bypassing the override" do
      renderer = renderer_with_bold_override { |_node, _interface| "OVERRIDDEN" }
      bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x")

      expect(renderer.render(bold)).to eq("OVERRIDDEN")
      expect(renderer.render_default(bold)).to eq("**x**")
    end

    it "lets an override delegate conditionally via the interface" do
      renderer =
        renderer_with_bold_override do |node, interface|
          if node.children.first&.text == "special"
            "!!special!!"
          else
            interface.render_default(node)
          end
        end

      special = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("special")
      plain = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("plain")
      document = Markbridge::AST::Document.new
      document << special << plain

      expect(renderer.render(document)).to eq("!!special!!**plain**")
    end

    it "keeps applying overrides inside the delegated subtree" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(
        Markbridge::AST::Italic,
        Markbridge::Renderers::Discourse::Tag.new { |_n, _i| "ITALIC-OVERRIDE" },
      )
      renderer = described_class.new(tag_library: library)
      quote = Markbridge::AST::Quote.new
      quote << Markbridge::AST::Italic.new

      # render_default bypasses only the Quote lookup; the Italic child
      # still renders through this renderer's (overridden) library.
      expect(renderer.render_default(quote)).to eq("\n\n> ITALIC-OVERRIDE\n\n")
    end

    it "falls back to the tag-less paths for node classes without a stock tag" do
      custom_class = Class.new(Markbridge::AST::Element)
      element = custom_class.new << Markbridge::AST::Text.new("inside")

      expect(renderer.render_default(element)).to eq("inside")
    end

    it "renders Text nodes through the escaper like #render does" do
      text = Markbridge::AST::Text.new("*not bold*")

      expect(renderer.render_default(text)).to eq("\\*not bold\\*")
    end

    it "reaches the stock base class tag for a subclass node" do
      subclass = Class.new(Markbridge::AST::Bold)
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(subclass, Markbridge::Renderers::Discourse::Tag.new { |_, _| "OWN" })
      renderer = described_class.new(tag_library: library)
      node = subclass.new << Markbridge::AST::Text.new("x")

      # The custom tag wins in #render; render_default skips it and finds
      # the stock BoldTag through the subclass's ancestry.
      expect(renderer.render(node)).to eq("OWN")
      expect(renderer.render_default(node)).to eq("**x**")
    end

    it "asks the default library to resolve each class once per render call" do
      subclass = Class.new(Markbridge::AST::Bold)
      fallback = Markbridge::Renderers::Discourse::Tag.new { |_, _| "STOCK" }
      default_library = instance_double(Markbridge::Renderers::Discourse::TagLibrary)
      allow(default_library).to receive(:[]).and_return(nil)
      allow(default_library).to receive(:resolve).and_return(fallback)
      allow(Markbridge::Renderers::Discourse::TagLibrary).to receive(:default).and_return(
        default_library,
      )

      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(
        subclass,
        Markbridge::Renderers::Discourse::Tag.new do |node, interface|
          interface.render_default(node)
        end,
      )
      renderer = described_class.new(tag_library: library)
      document = Markbridge::AST::Document.new
      document << subclass.new << subclass.new

      expect(renderer.render(document)).to eq("STOCKSTOCK")
      # Two subclass nodes, one ancestry walk against the default library.
      expect(default_library).to have_received(:resolve).with(subclass).once
    end
  end

  describe "#leading_list and #trailing_list" do
    let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
    let(:untagged) { Class.new(Markbridge::AST::Element) }
    let(:first) { Markbridge::AST::List.new }
    let(:last) { Markbridge::AST::List.new(ordered: true) }

    it "asks the tag of the node" do
      expect(renderer.leading_list(first, context)).to be(first)
      expect(renderer.trailing_list(first, context)).to be(first)
    end

    it "is nil for a node whose tag writes something of its own" do
      quote = Markbridge::AST::Quote.new << first

      expect(renderer.leading_list(quote, context)).to be_nil
      expect(renderer.trailing_list(quote, context)).to be_nil
    end

    it "is nil for text" do
      text = Markbridge::AST::Text.new("a")

      expect(renderer.leading_list(text, context)).to be_nil
      expect(renderer.trailing_list(text, context)).to be_nil
    end

    it "answers for the first and the last child of an element without a tag" do
      element = untagged.new << first << Markbridge::AST::Text.new("x") << last

      expect(renderer.leading_list(element, context)).to be(first)
      expect(renderer.trailing_list(element, context)).to be(last)
    end

    it "skips whitespace-only text at the edges of an element without a tag" do
      element = untagged.new
      element << Markbridge::AST::Text.new(" \n") << first << last <<
        Markbridge::AST::Text.new("\t")

      expect(renderer.leading_list(element, context)).to be(first)
      expect(renderer.trailing_list(element, context)).to be(last)
    end

    it "is nil for an element without a tag whose edges are not lists" do
      element = untagged.new << Markbridge::AST::Text.new("a") << first << Markbridge::AST::Bold.new

      expect(renderer.leading_list(element, context)).to be_nil
      expect(renderer.trailing_list(element, context)).to be_nil
    end

    it "is nil for an element without a tag and without children" do
      expect(renderer.leading_list(untagged.new, context)).to be_nil
      expect(renderer.trailing_list(untagged.new, context)).to be_nil
    end

    it "looks through nested elements without a tag" do
      inner = untagged.new << first
      element = untagged.new << Markbridge::AST::Text.new("") << inner

      expect(renderer.leading_list(element, context)).to be(first)
      expect(renderer.trailing_list(element, context)).to be(first)
    end

    it "answers for the children of a node with a tag when asked to" do
      quote = Markbridge::AST::Quote.new << first << last

      expect(renderer.leading_list(quote, context, children: true)).to be(first)
      expect(renderer.trailing_list(quote, context, children: true)).to be(last)
    end

    it "resets its caches after a call outside a render" do
      list =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        )

      renderer.leading_list(first, context)
      renderer.render(Markbridge::AST::Document.new << list)
      expect(renderer.list_marker(list)).to be_nil

      renderer.trailing_list(first, context)
      renderer.render(Markbridge::AST::Document.new << list)
      expect(renderer.list_marker(list)).to be_nil
    end

    context "with a tag that looks at the interface it gets" do
      let(:seen) { [] }
      let(:renderer) do
        hooks = seen
        tag =
          Class.new(Markbridge::Renderers::Discourse::Tag) do
            define_method(:render) { |element, interface| interface.render_children(element) }
            define_method(:leading_list) { |_element, interface| hooks << interface and nil }
            define_method(:trailing_list) { |_element, interface| hooks << interface and nil }
          end
        library = Markbridge::Renderers::Discourse::TagLibrary.default
        library.register(Markbridge::AST::Quote, tag.new)
        described_class.new(tag_library: library)
      end

      it "hands the hook the interface of the context" do
        quote = Markbridge::AST::Quote.new

        renderer.leading_list(quote, context)
        renderer.trailing_list(quote, context)

        expect(seen.map(&:context)).to eq([context, context])
      end

      it "hands the hook of a nested node the same context" do
        element = untagged.new << (Markbridge::AST::Quote.new << first)

        renderer.leading_list(element, context)
        renderer.trailing_list(element, context)

        expect(seen.map(&:context)).to eq([context, context])
      end
    end
  end

  describe "#choose_list_marker and #list_marker" do
    let(:first) { Markbridge::AST::List.new }

    it "picks the first marker of the kind for a node that is not the current child" do
      expect(renderer.choose_list_marker(first, ordered: false)).to eq("- ")
      expect(renderer.choose_list_marker(first, ordered: true)).to eq("1. ")
    end

    it "knows no marker for a node outside a render call" do
      expect(renderer.list_marker(first)).to be_nil
    end

    it "remembers the marker for the list during the render call" do
      item = Markbridge::AST::ListItem.new
      list = Markbridge::AST::List.new << item
      seen = nil
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(
        Markbridge::AST::ListItem,
        Markbridge::Renderers::Discourse::Tag.new do |_element, interface|
          seen = interface.list_marker(list)
          "x"
        end,
      )

      described_class.new(tag_library: library).render(Markbridge::AST::Document.new << list)

      expect(seen).to eq("- ")
    end

    it "forgets the markers after the render call" do
      list =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        )
      renderer.render(Markbridge::AST::Document.new << list)

      expect(renderer.list_marker(list)).to be_nil
    end

    it "resets its caches after a call outside a render" do
      renderer.choose_list_marker(first, ordered: false)
      list =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        )
      renderer.render(Markbridge::AST::Document.new << list)

      expect(renderer.list_marker(list)).to be_nil
    end

    it "picks the marker the list in front did not use, by identity of the node" do
      a =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        )
      b =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        )
      c =
        Markbridge::AST::List.new << (
          Markbridge::AST::ListItem.new << Markbridge::AST::Text.new("a")
        )

      # The three lists are equal in structure; only the node tells them apart.
      expect(renderer.render(Markbridge::AST::Document.new << a << b << c)).to eq(
        "\n\n- a\n\n\n\n\n* a\n\n\n\n\n- a\n\n\n",
      )
    end
  end

  describe "#render_children with a child whose output ends or starts with a list" do
    let(:untagged) { Class.new(Markbridge::AST::Element) }

    def list(text, ordered: false)
      Markbridge::AST::List.new(ordered:) << (
        Markbridge::AST::ListItem.new << Markbridge::AST::Text.new(text)
      )
    end

    # The blocks of the raw output are squeezed together, as the
    # postprocessor does it.
    def markdown(document, renderer = self.renderer)
      renderer.render(document).gsub(/\n{3,}/, "\n\n").strip
    end

    it "changes the marker of a list after the list at the end of an element without a tag" do
      document = Markbridge::AST::Document.new
      document << (untagged.new << list("a")) << list("b")

      expect(markdown(document)).to eq("- a\n\n* b")
    end

    it "changes the marker of the list at the start of an element without a tag" do
      document = Markbridge::AST::Document.new
      document << list("a") << (untagged.new << list("b"))

      expect(markdown(document)).to eq("- a\n\n* b")
    end

    it "keeps the marker for lists of different kinds" do
      document = Markbridge::AST::Document.new
      document << (untagged.new << list("a")) << list("b", ordered: true)

      expect(markdown(document)).to eq("- a\n\n1. b")
    end

    it "keeps the marker when the element writes text after its list" do
      document = Markbridge::AST::Document.new
      document << (untagged.new << list("a") << Markbridge::AST::Text.new("t")) << list("b")

      expect(markdown(document)).to eq("- a\n\nt\n\n- b")
    end

    it "keeps the marker when the element writes text before its list" do
      document = Markbridge::AST::Document.new
      document << list("a") << (untagged.new << Markbridge::AST::Text.new("t") << list("b"))

      expect(markdown(document)).to eq("- a\n\nt\n\n- b")
    end

    it "keeps the list in front in view across an element whose output is empty" do
      document = Markbridge::AST::Document.new
      document << list("a") << untagged.new << list("b")

      expect(markdown(document)).to eq("- a\n\n* b")
    end

    it "does not count an element whose list renders to nothing" do
      document = Markbridge::AST::Document.new
      document << (untagged.new << Markbridge::AST::List.new) << list("b")

      expect(markdown(document)).to eq("- b")
    end

    context "with a tag that opens with its first child" do
      # The hook answers only for the context the tag renders its
      # children in, with the element on top of the chain.
      let(:opener) { Class.new(Markbridge::AST::Element) }
      let(:tag_class) do
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def leading_list(element, interface)
            if interface.context.element.equal?(element)
              interface.leading_list(element, children: true)
            end
          end
        end
      end

      def renderer_with(tag)
        library = Markbridge::Renderers::Discourse::TagLibrary.default
        library.register(opener, tag)
        described_class.new(tag_library: library)
      end

      it "asks the hook with the context of the children" do
        tag =
          Class.new(tag_class) do
            def render(element, interface)
              interface.render_children(element, context: interface.with_parent(element))
            end
          end
        document = Markbridge::AST::Document.new << list("a") << (opener.new << list("b"))

        expect(markdown(document, renderer_with(tag.new))).to eq("- a\n\n* b")
      end

      it "keeps the list in front out of view when the hook says nil for the tokens context" do
        tag =
          Class.new(tag_class) do
            def render(element, interface)
              interface.render_tokens(element)
            end
          end
        document = Markbridge::AST::Document.new << list("a") << (opener.new << list("b"))

        expect(markdown(document, renderer_with(tag.new))).to eq("- a\n\n- b")
      end

      it "asks the hook with the context of the children rendered as tokens" do
        tag =
          Class.new(tag_class) do
            def render(element, interface)
              interface.render_tokens(element, context: interface.with_parent(element))
            end
          end
        document = Markbridge::AST::Document.new << list("a") << (opener.new << list("b"))

        expect(markdown(document, renderer_with(tag.new))).to eq("- a\n\n* b")
      end
    end
  end
end
