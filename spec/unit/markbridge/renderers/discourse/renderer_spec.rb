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

    it "does not escape ] in Text content when no link ancestor is present" do
      text = Markbridge::AST::Text.new("plain ] text")

      expect(renderer.render(text)).to eq("plain ] text")
    end

    it "escapes ] in Text content when context has a Url-subclass ancestor" do
      # Custom AST nodes that extend AST::Url inherit the in_link_label
      # escaping without any registration. (Tag dispatch is a separate
      # concern — TagLibrary is exact-class; this test exercises only
      # the renderer's ancestry-driven escape decision.)
      custom_url_class = Class.new(Markbridge::AST::Url)
      url = custom_url_class.new(href: "https://example.com")
      text = Markbridge::AST::Text.new("[A]")
      context = Markbridge::Renderers::Discourse::RenderContext.new([url])

      expect(renderer.render(text, context:)).to eq("\\[A\\]")
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

  describe "emissions" do
    let(:emitting_tag) do
      Class.new(Markbridge::Renderers::Discourse::Tag) do
        def render(_element, interface)
          interface.emit(:upload, { sha1: "abc" })
          "<<placeholder>>"
        end
      end
    end

    let(:bold_with_text) do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("x")
      Markbridge::AST::Document.new << bold
    end

    it "records Tag emissions during render and exposes them via #emissions" do
      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, emitting_tag.new)
      r = described_class.new(tag_library: library)

      result = r.render(bold_with_text)

      expect(result).to eq("<<placeholder>>")
      expect(r.emissions).to eq(upload: [{ sha1: "abc" }])
    end

    it "resets the buffer on each top-level render call" do
      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, emitting_tag.new)
      r = described_class.new(tag_library: library)

      r.render(bold_with_text)
      r.render(Markbridge::AST::Document.new)

      expect(r.emissions).to eq({})
    end

    it "discards emissions accumulated before the first render at the start of that render" do
      r = described_class.new
      r.record_emission(:stale, :before_render)

      r.render(Markbridge::AST::Document.new)

      expect(r.emissions).to eq({})
    end

    it "returns a deep snapshot — mutating an emitted-payloads array does not affect the buffer" do
      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, emitting_tag.new)
      r = described_class.new(tag_library: library)

      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("x")
      r.render(Markbridge::AST::Document.new << bold)

      first = r.emissions
      first[:upload].clear

      # A second call returns the original payload — the previous
      # caller's mutation didn't reach into the buffer.
      expect(r.emissions[:upload]).to eq([{ sha1: "abc" }])
    end
  end

  describe "#with_provisional_emissions" do
    let(:bold_with_text) do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("x")
      Markbridge::AST::Document.new << bold
    end

    it "rolls back emissions made inside the block when the block does not commit" do
      probing_tag =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_element, interface)
            interface.with_provisional_emissions do |_controller|
              interface.emit(:probe, :inner)
              "discarded"
            end
            interface.emit(:keep, :outer)
            "kept"
          end
        end

      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, probing_tag.new)
      r = described_class.new(tag_library: library)
      r.render(bold_with_text)

      expect(r.emissions).to eq(keep: [:outer])
    end

    it "keeps emissions when the block commits" do
      committing_tag =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_element, interface)
            interface.with_provisional_emissions do |controller|
              interface.emit(:probe, :inner)
              controller.commit
            end
            "ok"
          end
        end

      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, committing_tag.new)
      r = described_class.new(tag_library: library)
      r.render(bold_with_text)

      expect(r.emissions).to eq(probe: [:inner])
    end

    it "returns the block's value so callers can decide based on it" do
      r = described_class.new
      r.render(Markbridge::AST::Document.new) # initialize buffer

      result =
        r.with_provisional_emissions do |c|
          c.commit
          "the-value"
        end

      expect(result).to eq("the-value")
    end

    it "snapshots payload arrays deeply so a discarded inner emit does not leak" do
      # Emit a record before the provisional block; inside the
      # provisional block emit *more* records into the same key, then
      # discard. With a shallow snapshot (transform_keys), the inner
      # emits would persist because the snapshot's array is the same
      # object as the buffer's.
      preserving_tag =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_element, interface)
            interface.emit(:keep, :before)
            interface.with_provisional_emissions do |_c|
              interface.emit(:keep, :inner)
              "discarded"
            end
            "kept"
          end
        end

      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, preserving_tag.new)
      r = described_class.new(tag_library: library)
      r.render(bold_with_text)

      expect(r.emissions).to eq(keep: [:before])
    end
  end
end
