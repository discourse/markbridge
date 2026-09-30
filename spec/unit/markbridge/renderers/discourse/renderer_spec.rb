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
      result = described_class.new(html_escaper:).render(text, context:)

      expect(result).to eq("HTML-ESCAPED")
      expect(html_escaper).to have_received(:escape).with("a < b")
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

    it "renders elements using tag library" do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("bold text")

      result = renderer.render(bold)
      expect(result).to eq("**bold text**")
    end

    it "returns empty string for unknown node types" do
      unknown = Object.new
      result = renderer.render(unknown)
      expect(result).to eq("")
    end

    it "passes through MarkdownText.text without escaping" do
      node = Markbridge::AST::MarkdownText.new("**already** *bold*")

      expect(renderer.render(node)).to eq("**already** *bold*")
    end

    it "does not escape Text content when an ancestor is Code" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("a*b")

      # Code formatter wraps in backticks; the inner text must NOT be \-escaped.
      expect(renderer.render(code)).to include("a*b")
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

      expect(renderer.render(bold)).to include('a\*b')
    end

    it "escapes ] in Text content when an ancestor is Url (link-label context)" do
      url = Markbridge::AST::Url.new(href: "https://example.com")
      url << Markbridge::AST::Text.new("[A]")

      expect(renderer.render(url)).to eq("[\\[A\\]](https://example.com)")
    end

    it "escapes ] in Text content when an ancestor is Email (link-label context)" do
      email = Markbridge::AST::Email.new(address: "user@example.com")
      email << Markbridge::AST::Text.new("[A]")

      expect(renderer.render(email)).to eq("[\\[A\\]](mailto:user@example.com)")
    end

    it "escapes ] in Text content when an ancestor is Image (the alt text is a link label)" do
      image = Markbridge::AST::Image.new(src: "x.png")
      text = Markbridge::AST::Text.new("[A]")
      context = Markbridge::Renderers::Discourse::RenderContext.new([image])

      expect(renderer.render(text, context:)).to eq("\\[A\\]")
    end

    it "escapes ] in Text content under an Email subclass" do
      email_class = Class.new(Markbridge::AST::Email)
      context =
        Markbridge::Renderers::Discourse::RenderContext.new(
          [email_class.new(address: "alice@example.com")],
        )

      expect(renderer.render(Markbridge::AST::Text.new("[A]"), context:)).to eq("\\[A\\]")
    end

    it "escapes ] in Text content under an Image subclass" do
      image_class = Class.new(Markbridge::AST::Image)
      context = Markbridge::Renderers::Discourse::RenderContext.new([image_class.new(src: "x.png")])

      expect(renderer.render(Markbridge::AST::Text.new("[A]"), context:)).to eq("\\[A\\]")
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

    it "escapes ] in Text content when context has a Url-subclass ancestor" do
      # Custom AST nodes that extend AST::Url inherit the in_link_label
      # escaping without any registration. (This test exercises only the
      # renderer's ancestry-driven escape decision, not tag dispatch.)
      custom_url_class = Class.new(Markbridge::AST::Url)
      url = custom_url_class.new(href: "https://example.com")
      text = Markbridge::AST::Text.new("[A]")
      context = Markbridge::Renderers::Discourse::RenderContext.new([url])

      expect(renderer.render(text, context:)).to eq("\\[A\\]")
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

      it "puts the element on the parent chain under Tag::PASSTHROUGH" do
        code_subclass = Class.new(Markbridge::AST::Code)
        library = Markbridge::Renderers::Discourse::TagLibrary.default
        library.register(code_subclass, Markbridge::Renderers::Discourse::Tag::PASSTHROUGH)
        node = code_subclass.new << Markbridge::AST::Text.new("a*b")

        # Text under a Code ancestor is not Markdown-escaped, so the
        # children must have seen the element as their parent.
        expect(described_class.new(tag_library: library).render(node)).to eq("a*b")
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

  describe "#render_children" do
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

    it "checks against the part's FIRST char when deciding boundary insertion" do
      # Custom tag whose output starts with `*` but ends with non-delimiter `Z`.
      # Combined with a previous sibling ending in `*`, the boundary must be
      # inserted: result[-1] == "*" matches part[0] == "*", regardless of part[-1].
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      asym_class = Class.new(Markbridge::AST::Element)
      library.register(asym_class, Markbridge::Renderers::Discourse::Tag.new { |_e, _i| "*xyzZ" })
      r = described_class.new(tag_library: library)

      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("ab*")
      document << asym_class.new

      context = Markbridge::Renderers::Discourse::RenderContext.new

      expect(r.render_children(document, context:)).to eq("ab*<!---->*xyzZ")
    end

    it "checks against the result's LAST char when deciding boundary insertion" do
      # Three siblings: text "ab", text "*", Bold "x" → "**x**".
      # The boundary check must look at result[-1] ("*"), not result[0] ("a").
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("ab")
      document << Markbridge::AST::MarkdownText.new("*")
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("x")
      document << bold

      context = Markbridge::Renderers::Discourse::RenderContext.new

      expect(renderer.render_children(document, context:)).to eq("ab*<!---->**x**")
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

    it "inserts a comment boundary when sibling emphasis delimiters would merge" do
      # Two adjacent Bold siblings would render as **x****y** (four stars),
      # which CommonMark parses ambiguously. The renderer inserts an HTML
      # comment to force the delimiter runs to stay separate.
      document = Markbridge::AST::Document.new
      first = Markbridge::AST::Bold.new
      first << Markbridge::AST::Text.new("x")
      second = Markbridge::AST::Bold.new
      second << Markbridge::AST::Text.new("y")
      document << first
      document << second

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)

      expect(result).to eq("**x**<!---->**y**")
    end

    it "puts a boundary between a word and emphasis that starts with punctuation" do
      # `item*\#*` cannot open the emphasis: the `*` has a word character
      # in front and punctuation after it (CommonMark's flanking rules).
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("item")
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("#")
      document << italic

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("item<!---->*\\#*")
    end

    it "puts a boundary between emphasis that ends with punctuation and a word" do
      document = Markbridge::AST::Document.new
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("*bold*")
      document << bold
      document << Markbridge::AST::Text.new("tail")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("**\\*bold\\***<!---->tail")
    end

    it "puts a boundary between a word and strikethrough that starts with punctuation" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("w")
      strike = Markbridge::AST::Strikethrough.new
      strike << Markbridge::AST::Text.new("# heading")
      document << strike

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("w<!---->~~\\# heading~~")
    end

    it "treats a non-ASCII letter in front of the emphasis as a word character" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("ä")
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("#")
      document << italic

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("ä<!---->*\\#*")
    end

    it "leaves emphasis that starts with a word character alone" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("item")
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("x")
      document << italic

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("item*x*")
    end

    it "leaves emphasis alone when whitespace stands in front of it" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("item ")
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("#")
      document << italic

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("item *\\#*")
    end

    it "leaves emphasis alone when punctuation stands in front of it" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("(")
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("#")
      document << italic

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("(*\\#*")
    end

    it "leaves emphasis that ends with a word character alone in front of a word" do
      document = Markbridge::AST::Document.new
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("x")
      document << italic
      document << Markbridge::AST::Text.new("tail")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("*x*tail")
    end

    it "leaves emphasis that ends with punctuation alone in front of whitespace" do
      document = Markbridge::AST::Document.new
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("*bold*")
      document << bold
      document << Markbridge::AST::Text.new(" tail")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("**\\*bold\\*** tail")
    end

    it "puts a boundary between emphasis that ends with punctuation and strikethrough" do
      # cmark-gfm does not count the tilde as punctuation there, so the
      # closing `**` would stay text.
      document = Markbridge::AST::Document.new
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("a*")
      document << bold
      strike = Markbridge::AST::Strikethrough.new
      strike << Markbridge::AST::Text.new("b")
      document << strike

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("**a\\***<!---->~~b~~")
    end

    it "puts a boundary between strikethrough and emphasis that starts with punctuation" do
      document = Markbridge::AST::Document.new
      strike = Markbridge::AST::Strikethrough.new
      strike << Markbridge::AST::Text.new("a")
      document << strike
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("#")
      document << italic

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("~~a~~<!---->*\\#*")
    end

    it "leaves emphasis that ends with a word character alone in front of strikethrough" do
      document = Markbridge::AST::Document.new
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("a")
      document << bold
      strike = Markbridge::AST::Strikethrough.new
      strike << Markbridge::AST::Text.new("b")
      document << strike

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("**a**~~b~~")
    end

    # Renders two verbatim parts side by side and tells whether the
    # renderer put the boundary comment between them.
    def boundary_between?(before, part)
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new(before)
      document << Markbridge::AST::MarkdownText.new(part)
      context = Markbridge::Renderers::Discourse::RenderContext.new

      renderer.render_children(document, context:).include?("<!---->")
    end

    # Bytes at both ends of every range the word-character check uses,
    # with the byte next to each end. 0x80 is the first non-ASCII byte.
    {
      "/" => false,
      "0" => true,
      "9" => true,
      ":" => false,
      "@" => false,
      "A" => true,
      "Z" => true,
      "[" => false,
      "`" => false,
      "a" => true,
      "z" => true,
      "{" => false,
      "\x7F" => false,
      "\u0080" => true,
      "\u00E4" => true,
    }.each do |char, word|
      it "treats the byte #{char.bytes.last} in front of emphasis as #{word ? "a word" : "no word"} character" do
        expect(boundary_between?(char, "*\\#*")).to be(word)
      end
    end

    # The same for the punctuation check, on the byte after the run.
    # The `*` probe uses a tilde run, so the star does not join the run.
    {
      " " => false,
      "!" => true,
      "*" => true,
      "/" => true,
      "0" => false,
      "9" => false,
      ":" => true,
      "@" => true,
      "A" => false,
      "Z" => false,
      "[" => true,
      "`" => true,
      "a" => false,
      "z" => false,
      "{" => true,
      "~" => true,
      "\x7F" => false,
    }.each do |char, punctuation|
      it "treats the byte #{char.bytes.last} after the run as #{punctuation ? "punctuation" : "no punctuation"}" do
        run = char == "*" ? "~~" : "*"

        expect(boundary_between?("a", "#{run}#{char}x#{run}")).to be(punctuation)
      end
    end

    it "puts no boundary when the part is nothing but a delimiter run" do
      expect(boundary_between?("a", "**")).to be(false)
    end

    it "puts no boundary when the run reaches the start of the buffer" do
      expect(boundary_between?("**", "b")).to be(false)
    end

    it "looks past the whole run for the byte after it" do
      expect(boundary_between?("a", "***(x)***")).to be(true)
    end

    it "looks past the whole run for the byte before it" do
      expect(boundary_between?("(x)***", "tail")).to be(true)
    end

    it "does not take the last byte of the part for the byte after the run" do
      expect(boundary_between?("a", "*(x) tail")).to be(true)
    end

    it "puts a boundary between a word and an underscore run whatever follows the run" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("item")
      document << Markbridge::AST::MarkdownText.new("_x_")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("item<!---->_x_")
    end

    it "puts a boundary between an underscore run and a word whatever precedes the run" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("_x_")
      document << Markbridge::AST::Text.new("tail")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("_x_<!---->tail")
    end

    it "escapes a ! at the end of the buffer when the next part starts with [" do
      # Otherwise `![foo](/url)` cooks as an image.
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("Look!")
      link = Markbridge::AST::Url.new(href: "/url")
      link << Markbridge::AST::Text.new("foo")
      document << link

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("Look\\![foo](/url)")
    end

    it "leaves a ! that is already escaped alone" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("Look\\!")
      link = Markbridge::AST::Url.new(href: "/url")
      link << Markbridge::AST::Text.new("foo")
      document << link

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("Look\\![foo](/url)")
    end

    it "escapes a ! that follows an escaped backslash" do
      # `\\!` is an escaped backslash and an active `!`.
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("Look\\\\!")
      link = Markbridge::AST::Url.new(href: "/url")
      link << Markbridge::AST::Text.new("foo")
      document << link

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("Look\\\\\\![foo](/url)")
    end

    it "leaves a ! alone after an odd run of backslashes" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("Look\\\\\\!")
      link = Markbridge::AST::Url.new(href: "/url")
      link << Markbridge::AST::Text.new("foo")
      document << link

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("Look\\\\\\![foo](/url)")
    end

    it "counts a backslash run that reaches the start of the buffer" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("\\\\!")
      link = Markbridge::AST::Url.new(href: "/url")
      link << Markbridge::AST::Text.new("foo")
      document << link

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("\\\\\\![foo](/url)")
    end

    it "leaves a ! alone when the next part does not start with [" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::Text.new("Look!")
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("x")
      document << bold

      context = Markbridge::Renderers::Discourse::RenderContext.new
      expect(renderer.render_children(document, context:)).to eq("Look!**x**")
    end

    it "inserts a boundary between adjacent code spans so backtick runs don't merge" do
      # "`a``b`" would parse as ONE code span containing a``b, not two.
      document = Markbridge::AST::Document.new
      first = Markbridge::AST::Code.new
      first << Markbridge::AST::Text.new("a")
      second = Markbridge::AST::Code.new
      second << Markbridge::AST::Text.new("b")
      document << first
      document << second

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)

      expect(result).to eq("`a`<!---->`b`")
    end

    it "does not insert a boundary when adjacent characters are equal but non-delimiter" do
      # Two MarkdownText siblings (no auto-merge) ending/starting with the same letter.
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("a")
      document << Markbridge::AST::MarkdownText.new("a")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)

      expect(result).to eq("aa")
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

    it "appends what the block wrote to the buffer" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("a")
      document << Markbridge::AST::MarkdownText.new("b")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:) { |buffer, _child| buffer << "|" }

      expect(result).to eq("|a|b")
    end

    it "does not yield for a child that renders to an empty string" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("")
      document << Markbridge::AST::MarkdownText.new("b")

      context = Markbridge::Renderers::Discourse::RenderContext.new
      seen = []
      renderer.render_children(document, context:) { |_buffer, child| seen << child }

      expect(seen).to eq([document.children[1]])
    end

    it "applies the boundary rule to the last byte the block wrote" do
      document = Markbridge::AST::Document.new
      document << Markbridge::AST::MarkdownText.new("ab")
      italic = Markbridge::AST::Italic.new
      italic << Markbridge::AST::Text.new("x")
      document << italic

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:) { |buffer, _child| buffer << "*" }

      expect(result).to eq("*ab*<!---->*x*")
    end

    it "does not insert a boundary when delimiters differ" do
      document = Markbridge::AST::Document.new
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("x")
      strike = Markbridge::AST::Strikethrough.new
      strike << Markbridge::AST::Text.new("y")
      document << bold
      document << strike

      context = Markbridge::Renderers::Discourse::RenderContext.new
      result = renderer.render_children(document, context:)

      expect(result).to eq("**x**~~y~~")
    end
  end

  # The renderer decides what to put between two sibling outputs from a
  # table it packs once, while the class body runs. Mutation testing
  # cannot reach the rules behind it — a mutant redefines a method, and
  # by then the table is already built — so these examples take that job
  # instead. They walk every entry of both tables and compare it with the
  # rules written out longhand below. A change to a rule, to a byte
  # class or to the order of the class numbers fails here.
  describe "the join tables" do
    let(:byte_classes) { described_class.const_get(:BYTE_CLASSES) }
    let(:join_actions) { described_class.const_get(:JOIN_ACTIONS) }

    # The number a class or an action carries is an implementation
    # detail; the examples below talk in these names.
    let(:class_names) do
      {
        described_class.const_get(:OTHER) => :other,
        described_class.const_get(:WORD) => :word,
        described_class.const_get(:PUNCTUATION) => :punctuation,
        described_class.const_get(:BANG) => :bang,
        described_class.const_get(:BRACKET) => :bracket,
        described_class.const_get(:BACKTICK) => :backtick,
        described_class.const_get(:STAR) => :star,
        described_class.const_get(:UNDERSCORE) => :underscore,
        described_class.const_get(:TILDE) => :tilde,
      }
    end

    let(:action_names) do
      {
        described_class.const_get(:NOTHING) => :nothing,
        described_class.const_get(:BOUNDARY) => :boundary,
        described_class.const_get(:CHECK_AFTER) => :check_after,
        described_class.const_get(:CHECK_BEFORE) => :check_before,
        described_class.const_get(:ESCAPE_BANG) => :escape_bang,
      }
    end

    # One byte per class. The action table has a row per class of the
    # byte in front of the join, not a row per byte, so one byte stands
    # for its whole class there.
    let(:representatives) do
      {
        other: " ",
        word: "a",
        punctuation: "%",
        bang: "!",
        bracket: "[",
        backtick: "`",
        star: "*",
        underscore: "_",
        tilde: "~",
      }
    end

    # What a byte is to the join rules, written out longhand: the six
    # bytes the rules name, then CommonMark's word characters (ASCII
    # letters and digits, and every non-ASCII byte) and its ASCII
    # punctuation. Spaces and control bytes are neither.
    def expected_class(byte)
      case byte
      when "!".ord
        :bang
      when "[".ord
        :bracket
      when "`".ord
        :backtick
      when "*".ord
        :star
      when "_".ord
        :underscore
      when "~".ord
        :tilde
      when 48..57, 65..90, 97..122, 128..255
        :word
      when 33..47, 58..64, 91..96, 123..126
        :punctuation
      else
        :other
      end
    end

    # A word character keeps a delimiter run next to it from opening or
    # closing, and so does a tilde — cmark-gfm does not read `~` as
    # punctuation next to an emphasis delimiter.
    def blocking?(byte)
      expected_class(byte) == :word || byte == "~".ord
    end

    # The join rules, written out longhand over the byte in front of the
    # join and the byte after it, in the order the renderer applies
    # them.
    def expected_action(before, after)
      merging = "*_~`".bytes
      flanking = "*_~".bytes

      if before == after && merging.include?(before)
        :boundary
      elsif before == "!".ord && after == "[".ord
        :escape_bang
      elsif flanking.include?(after) && blocking?(before)
        after == "_".ord ? :boundary : :check_after
      elsif flanking.include?(before) && blocking?(after)
        before == "_".ord ? :boundary : :check_before
      else
        :nothing
      end
    end

    it "gives every class a number of its own" do
      expect(class_names.size).to eq(described_class.const_get(:CLASS_COUNT))
    end

    it "gives every action a number of its own" do
      expect(action_names.size).to eq(5)
    end

    it "holds a class for every byte" do
      expect(byte_classes.bytesize).to eq(256)
    end

    it "holds a row of 256 actions per class" do
      expect(join_actions.bytesize).to eq(class_names.size * 256)
    end

    it "classifies every byte the way the rules define it" do
      actual = (0..255).to_h { |byte| [byte, class_names.fetch(byte_classes.getbyte(byte))] }
      expected = (0..255).to_h { |byte| [byte, expected_class(byte)] }

      expect(actual).to eq(expected)
    end

    # The renderer asks whether a byte is punctuation with a single
    # `>=` against the class table, so every class that CommonMark
    # counts as punctuation has to sit at or above PUNCTUATION.
    it "numbers every punctuation class at or above PUNCTUATION" do
      names = %i[punctuation bang bracket backtick star underscore tilde]
      threshold = described_class.const_get(:PUNCTUATION)

      actual = (0..255).to_h { |byte| [byte, byte_classes.getbyte(byte) >= threshold] }
      expected = (0..255).to_h { |byte| [byte, names.include?(expected_class(byte))] }

      expect(actual).to eq(expected)
    end

    it "picks one byte per class to stand for it" do
      actual =
        representatives.transform_values do |char|
          class_names.fetch(byte_classes.getbyte(char.ord))
        end
      expected = representatives.keys.to_h { |name| [name, name] }

      expect(actual).to eq(expected)
    end

    it "picks the action the rules written out longhand pick" do
      actual = {}
      expected = {}

      representatives.each do |name, char|
        before = char.ord
        row = byte_classes.getbyte(before) << 8

        (0..255).each do |after|
          actual[[name, after]] = action_names.fetch(join_actions.getbyte(row + after))
          expected[[name, after]] = expected_action(before, after)
        end
      end

      expect(actual).to eq(expected)
    end
  end

  describe "RenderingInterface helpers" do
    let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
    let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

    it "returns true when content has newlines" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("line1\nline2")

      expect(interface.block_context?(code)).to be true
    end

    it "returns false when content has no newlines" do
      code = Markbridge::AST::Code.new
      code << Markbridge::AST::Text.new("single line")

      expect(interface.block_context?(code)).to be false
    end

    it "returns true for List elements" do
      list = Markbridge::AST::List.new(ordered: false)
      expect(interface.block_context?(list)).to be true
    end

    it "returns true for HorizontalRule elements" do
      hr = Markbridge::AST::HorizontalRule.new
      expect(interface.block_context?(hr)).to be true
    end

    it "wraps content with markers" do
      result = interface.wrap_inline("text", "**")
      expect(result).to eq("**text**")
    end

    it "uses different close marker if provided" do
      result = interface.wrap_inline("text", "[", "]")
      expect(result).to eq("[text]")
    end

    it "returns content as-is when empty after stripping" do
      result = interface.wrap_inline("   ", "**")
      expect(result).to eq("   ")
    end

    it "preserves leading whitespace" do
      result = interface.wrap_inline("  text", "**")
      expect(result).to eq("  **text**")
    end

    it "preserves trailing whitespace" do
      result = interface.wrap_inline("text  ", "**")
      expect(result).to eq("**text**  ")
    end

    it "uses HTML fallback when content contains markers" do
      result = interface.wrap_inline("text**more", "**")
      expect(result).to eq("<strong>text**more</strong>")
    end

    it "uses HTML fallback for italic conflicts" do
      result = interface.wrap_inline("text*more", "*")
      expect(result).to eq("<em>text*more</em>")
    end

    it "uses HTML fallback for strikethrough conflicts" do
      result = interface.wrap_inline("text~~more", "~~")
      expect(result).to eq("<s>text~~more</s>")
    end
  end

  describe "#render with a misbehaving custom tag" do
    it "raises a descriptive TypeError when a tag returns nil" do
      library = Markbridge::Renderers::Discourse::TagLibrary.default
      library.register(Markbridge::AST::Bold, Markbridge::Renderers::Discourse::Tag.new { nil })
      renderer = described_class.new(tag_library: library)
      bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x")

      expect { renderer.render(bold) }.to raise_error(TypeError, /must return a String/)
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
      expect(renderer.render_default(quote)).to include("ITALIC-OVERRIDE")
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
end
