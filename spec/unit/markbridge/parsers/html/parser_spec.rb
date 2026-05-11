# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Parser do
  let(:parser) { described_class.new }

  describe "#parse" do
    it "parses plain text" do
      doc = parser.parse("hello world")

      expect(doc).to be_a(Markbridge::AST::Document)
      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("hello world")
    end

    it "parses simple bold tag" do
      doc = parser.parse("<b>bold text</b>")

      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
      expect(doc.children[0].children[0].text).to eq("bold text")
    end

    it "parses nested tags" do
      doc = parser.parse("<b><i>nested</i></b>")

      bold = doc.children[0]
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(bold.children[0]).to be_a(Markbridge::AST::Italic)
      expect(bold.children[0].children[0].text).to eq("nested")
    end

    it "parses multiple tags" do
      doc = parser.parse("<b>bold</b> and <i>italic</i>")

      expect(doc.children.size).to eq(3)
      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
      expect(doc.children[1]).to be_a(Markbridge::AST::Text)
      expect(doc.children[1].text).to eq(" and ")
      expect(doc.children[2]).to be_a(Markbridge::AST::Italic)
    end

    it "handles line breaks" do
      doc = parser.parse("line 1<br>line 2")

      expect(doc.children.size).to eq(3)
      expect(doc.children[0].text).to eq("line 1")
      expect(doc.children[1]).to be_a(Markbridge::AST::LineBreak)
      expect(doc.children[2].text).to eq("line 2")
    end

    it "handles horizontal rules" do
      doc = parser.parse("text<hr>more")

      expect(doc.children.size).to eq(3)
      expect(doc.children[1]).to be_a(Markbridge::AST::HorizontalRule)
    end

    it "handles links with href" do
      doc = parser.parse('<a href="https://example.com">link</a>')

      link = doc.children[0]
      expect(link).to be_a(Markbridge::AST::Url)
      expect(link.href).to eq("https://example.com")
      expect(link.children[0].text).to eq("link")
    end

    it "handles images" do
      doc = parser.parse('<img src="photo.jpg" width="100" height="200">')

      img = doc.children[0]
      expect(img).to be_a(Markbridge::AST::Image)
      expect(img.src).to eq("photo.jpg")
      expect(img.width).to eq(100)
      expect(img.height).to eq(200)
    end

    it "handles unordered lists" do
      doc = parser.parse("<ul><li>item 1</li><li>item 2</li></ul>")

      list = doc.children[0]
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be false
      expect(list.children.size).to eq(2)
      expect(list.children[0]).to be_a(Markbridge::AST::ListItem)
      expect(list.children[1]).to be_a(Markbridge::AST::ListItem)
    end

    it "handles ordered lists" do
      doc = parser.parse("<ol><li>first</li><li>second</li></ol>")

      list = doc.children[0]
      expect(list).to be_a(Markbridge::AST::List)
      expect(list.ordered?).to be true
    end

    it "handles code blocks" do
      doc = parser.parse("<code>var x = 1;</code>")

      code = doc.children[0]
      expect(code).to be_a(Markbridge::AST::Code)
      expect(code.children[0].text).to eq("var x = 1;")
    end

    it "handles blockquotes" do
      doc = parser.parse("<blockquote>quoted text</blockquote>")

      quote = doc.children[0]
      expect(quote).to be_a(Markbridge::AST::Quote)
      expect(quote.children[0].text).to eq("quoted text")
    end

    it "creates Paragraph nodes for paragraph tags" do
      doc = parser.parse("<p>paragraph text</p>")

      # Paragraph handler creates AST::Paragraph nodes
      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[0].children.size).to eq(1)
      expect(doc.children[0].children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].children[0].text).to eq("paragraph text")
    end

    it "preserves paragraph boundaries for adjacent paragraphs" do
      doc = parser.parse("<p>One</p><p>Two</p>")

      # Each paragraph should be a separate Paragraph node
      expect(doc.children.size).to eq(2)
      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[0].children[0].text).to eq("One")
      expect(doc.children[1]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[1].children[0].text).to eq("Two")
    end

    it "drops style tag contents entirely" do
      doc = parser.parse("<style>.foo { color: red; }</style>hello")

      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("hello")
    end

    it "drops script tag contents entirely" do
      doc = parser.parse("<script>alert('xss')</script>hello")

      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("hello")
    end

    it "drops head subtree including nested style/title/meta" do
      html =
        "<html><head><title>T</title><style>.a{}</style></head>" \
          "<body>body text</body></html>"
      doc = parser.parse(html)

      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("body text")
    end

    it "does not count ignored tags as unknown" do
      parser.parse("<style>.a{}</style><script>x</script>")

      expect(parser.unknown_tags).to be_empty
    end

    it "tracks unknown tags" do
      parser.parse("<unknown>text</unknown>")

      expect(parser.unknown_tags).to have_key("unknown")
      expect(parser.unknown_tags["unknown"]).to eq(1)
    end

    it "increments the counter for repeated unknown tags" do
      parser.parse("<unknown>a</unknown><unknown>b</unknown>")

      expect(parser.unknown_tags["unknown"]).to eq(2)
    end

    it "clears unknown tags from a previous parse on the next parse" do
      parser.parse("<unknown>a</unknown>")
      expect(parser.unknown_tags).to have_key("unknown")

      parser.parse("<b>bold</b>")

      expect(parser.unknown_tags).to be_empty
    end

    it "ignores unknown tags while processing their children" do
      doc = parser.parse("<unknown>content</unknown>")

      expect(doc.children.size).to eq(1)
      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("content")
    end

    it "handles malformed HTML gracefully" do
      doc = parser.parse("<b>bold <i>italic</b></i>")

      # Nokogiri recovers from the mismatched tags. The exact tree shape is
      # parser-dependent (libxml2 reparents into <b><i>…</i></b>; JRuby's
      # NekoHTML leaves <b> and <i> as siblings), but the content survives
      # and the top-level node is always the <b>.
      expect(doc.children.first).to be_a(Markbridge::AST::Bold)

      collect_text = ->(node) do
        return node.text if node.is_a?(Markbridge::AST::Text)
        node.respond_to?(:children) ? node.children.map(&collect_text).join : ""
      end
      expect(collect_text.call(doc)).to include("bold", "italic")
    end

    it "handles empty input" do
      doc = parser.parse("")

      expect(doc.children).to be_empty
    end

    it "decodes HTML entities in text" do
      doc = parser.parse("&lt;b&gt; &amp; &quot;text&quot;")

      expect(doc.children[0].text).to eq("<b> & \"text\"")
    end

    it "collapses runs of whitespace to a single space per HTML spec" do
      doc = parser.parse("hello   world")

      expect(doc.children[0].text).to eq("hello world")
    end
  end

  describe "#parse whitespace handling" do
    it "preserves runs of whitespace inside <pre>" do
      doc = parser.parse("<pre>a   b</pre>")

      expect(doc.children[0].children[0].text).to eq("a   b")
    end

    it "preserves newlines inside <pre>" do
      doc = parser.parse("<pre>a\nb\nc</pre>")

      expect(doc.children[0].children[0].text).to eq("a\nb\nc")
    end

    it "preserves whitespace inside inline <code>" do
      doc = parser.parse("<code>a   b</code>")

      expect(doc.children[0].children[0].text).to eq("a   b")
    end

    it "preserves whitespace inside <textarea> via the ancestor walk" do
      # <textarea> has no handler, so handle_unknown_tag recurses into
      # children — preserves_whitespace? walks the ancestor chain and
      # finds <textarea> there, skipping the collapse.
      #
      # Single-level test only: libxml2 parses <textarea>'s inner HTML,
      # but NekoHTML (JRuby) treats <textarea> as RCDATA per HTML5 and
      # exposes the inner content as a literal text node, so we cannot
      # portably nest elements inside <textarea>.
      doc = parser.parse("<textarea>a   b</textarea>")

      expect(doc.children[0].text).to eq("a   b")
    end

    it "preserves whitespace inside <tt>" do
      doc = parser.parse("<tt>a   b</tt>")

      expect(doc.children[0].children[0].text).to eq("a   b")
    end

    it "collapses tabs and newlines as whitespace" do
      doc = parser.parse("a\tb\nc")

      expect(doc.children[0].text).to eq("a b c")
    end

    it "drops leading whitespace at the start of an element's content" do
      doc = parser.parse("<b>   text</b>")

      expect(doc.children[0].children[0].text).to eq("text")
    end

    it "does not append an empty Text node when leading whitespace is fully stripped" do
      # The text node "   " collapses to " ", then lstrip leaves "" — the
      # parser must skip it entirely rather than appending an empty Text.
      doc = parser.parse("<b>   <i>x</i></b>")

      bold = doc.children[0]
      expect(bold.children.size).to eq(1)
      expect(bold.children[0]).to be_a(Markbridge::AST::Italic)
    end

    it "trims trailing whitespace at the end of an element's content" do
      doc = parser.parse("<b>text   </b>")

      expect(doc.children[0].children[0].text).to eq("text")
    end

    it "preserves leading whitespace within a non-first text child while trimming only the trailing run" do
      # The "  bar  " text node is not the first child of <b>, so its
      # leading whitespace is preserved (matching the inline-whitespace
      # rule). Only trailing whitespace gets stripped.
      doc = parser.parse("<b>foo<i>x</i>  bar  </b>")

      bold = doc.children[0]
      expect(bold.children.last.text).to eq(" bar")
    end

    it "leaves an element's children alone when the last child is not a Text node" do
      # No trailing-whitespace work to do; a list ending in a <li>
      # should keep its ListItem as the last child unchanged.
      doc = parser.parse("<ul><li>x</li></ul>")

      list = doc.children[0]
      expect(list.children.size).to eq(1)
      expect(list.children.last).to be_a(Markbridge::AST::ListItem)
    end

    it "leaves a non-last Text sibling untouched when the last child is an element" do
      # Inspects the LAST child, not the first. With a non-Text last
      # child, no trim happens — and the earlier Text sibling keeps any
      # trailing whitespace it had after collapse.
      doc = parser.parse("<b>foo  <i>x</i></b>")

      bold = doc.children[0]
      expect(bold.children.size).to eq(2)
      expect(bold.children[0]).to be_a(Markbridge::AST::Text)
      expect(bold.children[0].text).to eq("foo ")
      expect(bold.children[1]).to be_a(Markbridge::AST::Italic)
    end

    it "drops a trailing Text child entirely when stripping leaves it empty" do
      # The "   " text becomes " " after collapse, then rstrip leaves "" —
      # the Text node must not stay in children as an empty placeholder.
      doc = parser.parse("<b><i>x</i>   </b>")

      bold = doc.children[0]
      expect(bold.children.size).to eq(1)
      expect(bold.children[0]).to be_a(Markbridge::AST::Italic)
    end

    it "drops a whitespace-only text node entirely at the start of the document" do
      doc = parser.parse("   hello")

      expect(doc.children.size).to eq(1)
      expect(doc.children[0].text).to eq("hello")
    end

    it "drops a whitespace-only text node entirely at the end of the document" do
      doc = parser.parse("hello   ")

      expect(doc.children.size).to eq(1)
      expect(doc.children[0].text).to eq("hello")
    end

    it "drops trailing whitespace before a block-level <p>" do
      doc = parser.parse("text   <p>para</p>")

      expect(doc.children[0].text).to eq("text")
    end

    it "drops trailing whitespace before a block-level <hr>" do
      doc = parser.parse("text   <hr>")

      expect(doc.children[0].text).to eq("text")
    end

    it "drops trailing whitespace before a block-level <ul>" do
      doc = parser.parse("text   <ul><li>x</li></ul>")

      expect(doc.children[0].text).to eq("text")
    end

    it "preserves trailing whitespace before an inline <br>" do
      # <br> is inline (LineBreak is not block-level), so the space before it
      # stays — matching browser behavior.
      doc = parser.parse("text <br>more")

      expect(doc.children[0].text).to eq("text ")
    end

    it "preserves whitespace inside the parent before an inline child" do
      # The space between text and <b> is meaningful inline whitespace.
      doc = parser.parse("foo <b>bar</b>")

      expect(doc.children[0].text).to eq("foo ")
    end

    it "does not trim trailing whitespace for whitespace-preserving tags" do
      # When a custom registry uses a handler that recurses into children
      # (returning ast_element) for a whitespace-preserving tag, the
      # post-recursion trim must skip — otherwise trailing whitespace
      # inside <pre>/<code>/<tt>/<textarea> would be dropped.
      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.register(
        "pre",
        Markbridge::Parsers::HTML::Handlers::SimpleHandler.new(Markbridge::AST::Code),
      )
      custom_parser = described_class.new(handlers: registry)

      doc = custom_parser.parse("<pre>foo   </pre>")

      pre = doc.children[0]
      expect(pre).to be_a(Markbridge::AST::Code)
      expect(pre.children[0].text).to eq("foo   ")
    end

    it "treats a handler with nil element_class as non-block" do
      # SpanHandler inherits `attr_reader :element_class` but never sets it,
      # so produces_block? must guard against the nil — otherwise comparing
      # nil < AST::Block would raise.
      expect { parser.parse('text   <span style="font-weight:bold">x</span>') }.not_to raise_error
    end

    it "trims trailing whitespace before a Block node emitted by an undeclared handler" do
      # Custom handler that picks the AST class at runtime (so it can't
      # advertise `element_class` upfront). When the appended node is Block
      # the parser must retroactively trim the Text sibling that preceded it.
      custom_handler =
        Class
          .new(Markbridge::Parsers::HTML::Handlers::BaseHandler) do
            def process(element:, parent:)
              paragraph = Markbridge::AST::Paragraph.new
              parent << paragraph
              paragraph
            end
          end
          .new

      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.register("custom-p", custom_handler)
      custom_parser = described_class.new(handlers: registry)

      # Nest inside <blockquote> so the document-level final trim doesn't
      # mask the per-element trim under test.
      doc = custom_parser.parse("<blockquote>text   <custom-p></custom-p></blockquote>")

      quote = doc.children[0]
      expect(quote.children.size).to eq(2)
      expect(quote.children[0]).to be_a(Markbridge::AST::Text)
      expect(quote.children[0].text).to eq("text")
      expect(quote.children[1]).to be_a(Markbridge::AST::Paragraph)
    end

    it "skips the post-handler trim when the returned Block was not appended to parent" do
      # Identity check (parent.children.last.equal?(ast_element)) guards
      # against handlers that return a Block-typed node without actually
      # adding it to the tree. Setup: the parent already has
      # [Text("a "), Italic] when the ghost handler fires — if the guard
      # were missing, Text("a ") at [-2] would be wrongly stripped.
      custom_handler =
        Class
          .new(Markbridge::Parsers::HTML::Handlers::BaseHandler) do
            def process(element:, parent:)
              # Returned but intentionally not appended.
              Markbridge::AST::Paragraph.new
            end
          end
          .new

      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.register("ghost-p", custom_handler)
      custom_parser = described_class.new(handlers: registry)

      doc = custom_parser.parse("<blockquote>a <i>x</i><ghost-p></ghost-p>!</blockquote>")

      quote = doc.children[0]
      expect(quote.children.size).to eq(3)
      expect(quote.children[0]).to be_a(Markbridge::AST::Text)
      expect(quote.children[0].text).to eq("a ")
      expect(quote.children[1]).to be_a(Markbridge::AST::Italic)
      expect(quote.children[2].text).to eq("!")
    end

    it "preserves leading whitespace on the trimmed Text — only trailing is stripped" do
      # When the Text sibling preceding a Block has leading whitespace
      # (because it's not the first child of its parent), trim_text_before_last
      # must rstrip only — strip or lstrip would lose the inline leading
      # space.
      custom_handler =
        Class
          .new(Markbridge::Parsers::HTML::Handlers::BaseHandler) do
            def process(element:, parent:)
              paragraph = Markbridge::AST::Paragraph.new
              parent << paragraph
              paragraph
            end
          end
          .new

      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.register("custom-p", custom_handler)
      custom_parser = described_class.new(handlers: registry)

      doc = custom_parser.parse("<blockquote>x<i>y</i>  text  <custom-p></custom-p></blockquote>")

      quote = doc.children[0]
      # Quote.children: [Text("x"), Italic, Text(" text"), Paragraph]
      expect(quote.children[-2]).to be_a(Markbridge::AST::Text)
      expect(quote.children[-2].text).to eq(" text")
    end

    it "does not trim when the handler's returned node is not a Block" do
      # A handler may produce an inline AST node and still not advertise
      # element_class (e.g. SpanHandler picks Bold/Italic/etc. at runtime).
      # The fallback must skip the trim for inline returns.
      custom_handler =
        Class
          .new(Markbridge::Parsers::HTML::Handlers::BaseHandler) do
            def process(element:, parent:)
              bold = Markbridge::AST::Bold.new
              parent << bold
              bold
            end
          end
          .new

      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.register("custom-b", custom_handler)
      custom_parser = described_class.new(handlers: registry)

      doc = custom_parser.parse("<blockquote>text   <custom-b></custom-b></blockquote>")

      quote = doc.children[0]
      expect(quote.children[0]).to be_a(Markbridge::AST::Text)
      expect(quote.children[0].text).to eq("text ")
    end

    it "drops a Proc handler's pre-trim because it does not advertise an element class" do
      # Proc handlers don't expose element_class; produces_block? returns
      # false for them, so trailing whitespace is left intact even though
      # the Proc emits a HorizontalRule.
      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.register(
        "hr",
        ->(element:, parent:) { parent << Markbridge::AST::HorizontalRule.new },
      )
      proc_parser = described_class.new(handlers: registry)

      doc = proc_parser.parse("text <hr>")

      expect(doc.children[0].text).to eq("text ")
    end
  end

  describe "#initialize" do
    it "initializes unknown_tags as a counting hash defaulting to 0" do
      expect(parser.unknown_tags).to be_empty
      expect(parser.unknown_tags["never-seen"]).to eq(0)
    end

    it "routes parsing through a custom handlers registry when one is passed" do
      custom_registry = Markbridge::Parsers::HTML::HandlerRegistry.new
      custom_registry.register(
        "b",
        Markbridge::Parsers::HTML::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      parser = described_class.new(handlers: custom_registry)
      doc = parser.parse("<b>test</b>")

      expect(doc.children[0]).to be_a(Markbridge::AST::Italic)
    end

    it "invokes the block with the default registry and uses the resulting handlers" do
      parser =
        described_class.new do |registry|
          registry.register(
            "b",
            Markbridge::Parsers::HTML::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
          )
        end
      doc = parser.parse("<b>test</b>")

      expect(doc.children[0]).to be_a(Markbridge::AST::Italic)
    end

    it "falls back to the default registry when no block and no handlers are given" do
      parser = described_class.new

      doc = parser.parse("<b>test</b>")
      expect(doc.children[0]).to be_a(Markbridge::AST::Bold)
    end
  end
end
