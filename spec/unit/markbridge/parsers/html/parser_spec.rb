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

  describe "#parse with pre-parsed Nokogiri input" do
    it "accepts a Nokogiri DocumentFragment directly without re-parsing" do
      fragment = Nokogiri::HTML.fragment("<p>hello <b>world</b></p>")
      doc = parser.parse(fragment)

      paragraph = doc.children[0]
      expect(paragraph).to be_a(Markbridge::AST::Paragraph)
      expect(paragraph.children[0].text).to eq("hello ")
      expect(paragraph.children[1]).to be_a(Markbridge::AST::Bold)
    end

    it "lets caller pre-mutate the fragment before parsing" do
      # Demonstrates the importer use case: parse once with Nokogiri,
      # walk and rewrite the tree, hand the same fragment to Markbridge.
      fragment = Nokogiri::HTML.fragment("<p>before</p><div>middle</div><p>after</p>")
      fragment.at_css("div").unlink

      doc = parser.parse(fragment)

      paragraphs = doc.children.select { |c| c.is_a?(Markbridge::AST::Paragraph) }
      expect(paragraphs.size).to eq(2)
      expect(paragraphs[0].children[0].text).to eq("before")
      expect(paragraphs[1].children[0].text).to eq("after")
    end

    it "iterates the children of a bare Nokogiri::XML::Element (one level down)" do
      # Same shape as DocumentFragment: process_node is called on each
      # of the element's direct children. Passing a <div> wrapping a <p>
      # therefore yields a top-level Paragraph in the AST.
      element = Nokogiri::HTML.fragment("<div><p>inside</p></div>").at_css("div")
      doc = parser.parse(element)

      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[0].children[0].text).to eq("inside")
    end

    it "does not re-invoke Nokogiri::HTML.fragment when given a pre-parsed tree" do
      # The whole point of accepting Nokogiri input: skip the parse +
      # serialize round-trip that would otherwise re-encode URL bytes
      # and force callers to short-circuit with marker-based prechecks.
      fragment = Nokogiri::HTML.fragment("<p>x</p>")
      allow(Nokogiri::HTML).to receive(:fragment)

      parser.parse(fragment)

      expect(Nokogiri::HTML).not_to have_received(:fragment)
    end

    it "unwraps a full Nokogiri::HTML::Document to its <body> children" do
      # Nokogiri::HTML.parse returns a full Document with synthesized
      # <html>/<head>/<body> wrappers. Iterating the document's direct
      # children would surface <html> as an unknown tag and then re-
      # descend through <head>/<body>. Unwrap to <body>.children so a
      # Document behaves like the natural Fragment input.
      html_doc = Nokogiri::HTML.parse("<html><body><p>hi</p></body></html>")
      doc = parser.parse(html_doc)

      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[0].children[0].text).to eq("hi")
      expect(parser.unknown_tags).to be_empty
    end

    it "does not run the <body>-unwrap path for non-HTML::Document inputs" do
      # The body-unwrap fires for Nokogiri::HTML::Document only. A bare
      # Nokogiri::XML::Document — even one that *contains* a <body>
      # element — iterates its own children as-is; the body surfaces in
      # unknown_tags like any other unrecognised wrapper rather than
      # being silently treated as the document root.
      xml_doc = Nokogiri.XML("<root><body><p>x</p></body></root>")
      parser.parse(xml_doc)

      expect(parser.unknown_tags["root"]).to eq(1)
      expect(parser.unknown_tags["body"]).to eq(1)
    end

    it "falls back to the document's own children when a Document has no <body>" do
      # Malformed: an HTML document without a body. We don't crash; we
      # iterate the document's direct children so unknown wrappers still
      # surface in unknown_tags rather than disappearing silently.
      html_doc = Nokogiri::HTML::Document.new
      html_doc << Nokogiri::XML::Element.new("p", html_doc).tap { |p| p.content = "stray" }
      doc = parser.parse(html_doc)

      expect(doc.children).not_to be_empty
    end

    it "treats any Nokogiri::XML::Node subclass as pre-parsed input" do
      # is_a?(Nokogiri::XML::Node) covers all of: DocumentFragment,
      # Document, Element. instance_of?(Node) would reject every one
      # of them because none is a bare Node — they're all subclasses.
      fragment = Nokogiri::HTML.fragment("<p>x</p>")
      expect(fragment).not_to be_instance_of(Nokogiri::XML::Node)
      allow(Nokogiri::HTML).to receive(:fragment)

      parser.parse(fragment)

      expect(Nokogiri::HTML).not_to have_received(:fragment)
    end

    it "still coerces non-String inputs via to_s when they are not Nokogiri nodes" do
      # Pathname / IO-like objects keep working through the to_s fallback.
      coercible =
        Class.new do
          def to_s
            "<p>via to_s</p>"
          end
        end
      doc = parser.parse(coercible.new)

      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[0].children[0].text).to eq("via to_s")
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

    it "preserves whitespace inside <textarea> even though it has no handler" do
      # <textarea> has no handler, so handle_unknown_tag recurses into
      # children — the preserve-depth tracking must cover the unknown-tag
      # path too, not just handled tags.
      #
      # Single-level test only: libxml2 parses <textarea>'s inner HTML,
      # but NekoHTML (JRuby) treats <textarea> as RCDATA per HTML5 and
      # exposes the inner content as a literal text node, so we cannot
      # portably nest elements inside <textarea>.
      doc = parser.parse("<textarea>a   b</textarea>")

      expect(doc.children[0].text).to eq("a   b")
    end

    it "stops preserving whitespace after the preserving element closes" do
      doc = parser.parse("<p><code>a   b</code> and   after</p>")

      paragraph = doc.children[0]
      expect(paragraph.children[0].children[0].text).to eq("a   b")
      expect(paragraph.children[1].text).to eq(" and after")
    end

    it "stops preserving whitespace after an unregistered preserving tag closes" do
      # <textarea> has no handler, so preservation must be switched on
      # and off around the unknown-tag path as well; the sibling text
      # after it collapses normally.
      doc = parser.parse("<div><textarea>a   b</textarea>c   d</div>")

      # Both texts land in the same parent and merge into one node:
      # "a   b" kept verbatim, "c   d" collapsed.
      expect(doc.children[0].text).to eq("a   bc d")
    end

    it "preserves whitespace when the parse root itself is a <pre> element" do
      pre = Nokogiri::HTML.fragment("<pre>a   b</pre>").at_css("pre")
      doc = parser.parse(pre)

      expect(doc.children[0].text).to eq("a   b")
    end

    it "preserves whitespace when the parse root sits inside a <pre> ancestor" do
      span = Nokogiri::HTML.fragment("<pre><span>a   b</span></pre>").at_css("span")
      doc = parser.parse(span)

      expect(doc.children[0].text).to eq("a   b")
    end

    it "does not preserve whitespace for a parse root under non-preserving ancestors" do
      # Guards the seeded counter: only whitespace-preserving ancestors
      # may count, not just any ancestors.
      span = Nokogiri::HTML.fragment("<div><span>a   b</span></div>").at_css("span")
      doc = parser.parse(span)

      expect(doc.children[0].text).to eq("a b")
    end

    it "keeps preserving whitespace after a non-preserving child element closes" do
      # A custom preserving tag without a handler is the only way to get
      # the parser to walk children in preserving mode (pre/code/tt use
      # RawHandler, which flattens content without walking).
      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.whitespace_preserving_tags << "poem"
      custom_parser = described_class.new(handlers: registry)

      doc = custom_parser.parse("<poem><b>x</b>a   b</poem>")

      poem_children = doc.children
      expect(poem_children[0]).to be_a(Markbridge::AST::Bold)
      expect(poem_children[1].text).to eq("a   b")
    end

    it "keeps preserving whitespace after a nested preserving element closes" do
      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.whitespace_preserving_tags << "poem"
      custom_parser = described_class.new(handlers: registry)

      doc = custom_parser.parse("<poem><poem>a   b</poem>c   d</poem>")

      expect(doc.children[0].text).to eq("a   bc   d")
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

    it "trims trailing whitespace before an unknown block-level tag like <div>" do
      # <div> has no handler in the default registry but is in
      # block_level_tags, so the boundary trim still fires. Realistic
      # Outlook output: <p>after</p>\n<div>raw</div><p>following</p>.
      # Without the trim, the "\n" between </p> and <div> survives as a
      # leading space on "raw".
      doc = parser.parse("<p>before</p>\n<div>raw</div><p>after</p>")

      expect(doc.children.size).to eq(3)
      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children[1]).to be_a(Markbridge::AST::Text)
      expect(doc.children[1].text).to eq("raw")
      expect(doc.children[2]).to be_a(Markbridge::AST::Paragraph)
    end

    it "does not trim trailing whitespace before an inline tag like <span>" do
      # <span> is not in block_level_tags, so its preceding whitespace is
      # preserved as part of the inline flow.
      doc = parser.parse('text <span style="font-weight:bold">x</span>')

      expect(doc.children[0]).to be_a(Markbridge::AST::Text)
      expect(doc.children[0].text).to eq("text ")
    end

    it "lets a consumer extend block_level_tags to cover custom tags" do
      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.block_level_tags << "my-block"
      custom_parser = described_class.new(handlers: registry)

      # Same shape as the <div> test: leading-space-before-block context.
      doc = custom_parser.parse("<p>before</p>\n<my-block>raw</my-block>")

      expect(doc.children[0]).to be_a(Markbridge::AST::Paragraph)
      # No leading space on "raw" — the "\n" between </p> and <my-block>
      # got trimmed via the customized block_level_tags.
      expect(doc.children[1]).to be_a(Markbridge::AST::Text)
      expect(doc.children[1].text).to eq("raw")
    end

    it "lets a consumer remove a tag from block_level_tags" do
      # Removing <hr> from block_level_tags makes it behave like an
      # inline tag for whitespace purposes — the preceding space stays.
      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.block_level_tags.delete("hr")
      custom_parser = described_class.new(handlers: registry)

      doc = custom_parser.parse("text <hr>")

      expect(doc.children[0].text).to eq("text ")
    end

    it "lets a consumer extend whitespace_preserving_tags to cover custom tags" do
      registry = Markbridge::Parsers::HTML::HandlerRegistry.default
      registry.whitespace_preserving_tags << "code-snippet"
      custom_parser = described_class.new(handlers: registry)

      # <code-snippet> has no handler, so handle_unknown_tag recurses; the
      # ancestor walk in preserves_whitespace? finds it on the chain.
      doc = custom_parser.parse("<code-snippet>a   b</code-snippet>")

      expect(doc.children[0].text).to eq("a   b")
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
