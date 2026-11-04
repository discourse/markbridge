# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UrlTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders URL with valid href" do
      element = Markbridge::AST::Url.new(href: "https://example.com")
      element << Markbridge::AST::Text.new("Example")

      result = tag.render(element, interface)
      expect(result).to eq("[Example](https://example.com)")
    end

    it "escapes parentheses in the destination" do
      element = Markbridge::AST::Url.new(href: "https://example.com/a(b)c)")
      element << Markbridge::AST::Text.new("Example")

      expect(tag.render(element, interface)).to eq("[Example](https://example.com/a\\(b\\)c\\))")
    end

    it "doubles a backslash in the destination" do
      # `\)` would escape the parenthesis that closes the destination, and
      # `\\)` right before a closing parenthesis of the href would escape
      # only the backslash and end the destination at that parenthesis.
      trailing = Markbridge::AST::Url.new(href: "https://example.com/a\\")
      trailing << Markbridge::AST::Text.new("Example")
      before_paren = Markbridge::AST::Url.new(href: "https://example.com/a\\)b")
      before_paren << Markbridge::AST::Text.new("Example")

      expect(tag.render(trailing, interface)).to eq("[Example](https://example.com/a\\\\)")
      expect(tag.render(before_paren, interface)).to eq("[Example](https://example.com/a\\\\\\)b)")
    end

    it "escapes parentheses inside a destination that also needs angle brackets" do
      element = Markbridge::AST::Url.new(href: "Main (Page)")
      element << Markbridge::AST::Text.new("Example")

      expect(tag.render(element, interface)).to eq("[Example](<Main \\(Page\\)>)")
    end

    it "leaves a destination without parentheses alone" do
      element = Markbridge::AST::Url.new(href: "https://example.com/a?b=c&d=e")
      element << Markbridge::AST::Text.new("Example")

      expect(tag.render(element, interface)).to eq("[Example](https://example.com/a?b=c&d=e)")
    end

    it "renders http URLs" do
      element = Markbridge::AST::Url.new(href: "http://example.com")
      element << Markbridge::AST::Text.new("Example")

      result = tag.render(element, interface)
      expect(result).to eq("[Example](http://example.com)")
    end

    it "renders https URLs" do
      element = Markbridge::AST::Url.new(href: "https://secure.com")
      element << Markbridge::AST::Text.new("Secure")

      result = tag.render(element, interface)
      expect(result).to eq("[Secure](https://secure.com)")
    end

    it "renders mailto URLs" do
      element = Markbridge::AST::Url.new(href: "mailto:test@example.com")
      element << Markbridge::AST::Text.new("Email")

      result = tag.render(element, interface)
      expect(result).to eq("[Email](mailto:test@example.com)")
    end

    it "returns text only for invalid href" do
      element = Markbridge::AST::Url.new(href: "javascript:alert(1)")
      element << Markbridge::AST::Text.new("Bad Link")

      result = tag.render(element, interface)
      expect(result).to eq("Bad Link")
    end

    it "returns text only when href is nil" do
      element = Markbridge::AST::Url.new
      element << Markbridge::AST::Text.new("No Link")

      result = tag.render(element, interface)
      expect(result).to eq("No Link")
    end

    it "renders ftp URLs" do
      element = Markbridge::AST::Url.new(href: "ftp://files.example.com")
      element << Markbridge::AST::Text.new("Files")

      expect(tag.render(element, interface)).to eq("[Files](ftp://files.example.com)")
    end

    it "renders ftps URLs" do
      element = Markbridge::AST::Url.new(href: "ftps://files.example.com")
      element << Markbridge::AST::Text.new("Files")

      expect(tag.render(element, interface)).to eq("[Files](ftps://files.example.com)")
    end

    it "renders uppercase scheme URLs (case-insensitive matching)" do
      element = Markbridge::AST::Url.new(href: "HTTPS://Example.COM")
      element << Markbridge::AST::Text.new("Example")

      expect(tag.render(element, interface)).to eq("[Example](HTTPS://Example.COM)")
    end

    it "rejects hrefs that contain a valid scheme but do not start with one" do
      element = Markbridge::AST::Url.new(href: "javascript:https://hidden.example.com")
      element << Markbridge::AST::Text.new("Bad Link")

      expect(tag.render(element, interface)).to eq("Bad Link")
    end

    it "rejects hrefs whose valid scheme appears only after a newline (\\A vs ^)" do
      # Defends against a multi-line href like "javascript:x\nhttps://attacker"
      # slipping past the scheme check.
      element = Markbridge::AST::Url.new(href: "javascript:foo\nhttps://attacker.example.com")
      element << Markbridge::AST::Text.new("Bad Link")

      expect(tag.render(element, interface)).to eq("Bad Link")
    end

    it "escapes ] in the label so it does not terminate the link early" do
      element = Markbridge::AST::Url.new(href: "https://example.com")
      element << Markbridge::AST::Text.new("[ABC-123] some title")

      result = tag.render(element, interface)
      expect(result).to eq("[\\[ABC-123\\] some title](https://example.com)")
    end

    it "escapes every ] in the label" do
      element = Markbridge::AST::Url.new(href: "https://example.com")
      element << Markbridge::AST::Text.new("[A] and [B]")

      result = tag.render(element, interface)
      expect(result).to eq("[\\[A\\] and \\[B\\]](https://example.com)")
    end

    it "preserves structural ] in child markdown (e.g. an image's empty alt)" do
      element = Markbridge::AST::Url.new(href: "https://example.com/page")
      element << Markbridge::AST::Image.new(src: "https://example.com/logo.png")

      result = tag.render(element, interface)
      expect(result).to eq("[![](https://example.com/logo.png)](https://example.com/page)")
    end

    let(:element_class) { Markbridge::AST::Url }
    let(:element_factory) { Markbridge::AST::Url.new(href: "https://example.com") }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders as <a href> for valid hrefs" do
        element = Markbridge::AST::Url.new(href: "https://example.com")
        element << Markbridge::AST::Text.new("Example")

        expect(tag.render(element, interface)).to eq(%(<a href="https://example.com">Example</a>))
      end

      it "attribute-escapes the href" do
        element = Markbridge::AST::Url.new(href: %(https://example.com/?a="b"&c=<d>))
        element << Markbridge::AST::Text.new("X")

        expect(tag.render(element, interface)).to eq(
          %(<a href="https://example.com/?a=&quot;b&quot;&amp;c=&lt;d&gt;">X</a>),
        )
      end

      it "falls back to plain text for invalid schemes" do
        element = Markbridge::AST::Url.new(href: "javascript:alert(1)")
        element << Markbridge::AST::Text.new("Bad")

        expect(tag.render(element, interface)).to eq("Bad")
      end
    end

    context "with bare URLs" do
      it "renders the plain href when the only text equals the href" do
        # A bare URL autolinks (and can onebox) in Discourse; a
        # [url](url) Markdown link does not.
        element = Markbridge::AST::Url.new(href: "https://example.com/t/5")
        element << Markbridge::AST::Text.new("https://example.com/t/5")

        expect(tag.render(element, interface)).to eq("https://example.com/t/5")
      end

      it "renders the plain href when there is no link text" do
        element = Markbridge::AST::Url.new(href: "https://example.com")

        expect(tag.render(element, interface)).to eq("https://example.com")
      end

      it "renders the plain href when the label renders to nothing" do
        # Not bare on the AST (a non-Text child exists), but the child
        # produces no output — `[](url)` would show nothing.
        element = Markbridge::AST::Url.new(href: "https://example.com")
        element << Markbridge::AST::Bold.new

        expect(tag.render(element, interface)).to eq("https://example.com")
      end

      it "renders the plain href when the label is only whitespace" do
        # The HTML parser keeps a space at an inline element's edge, so
        # `<a href="…"> </a>` reaches the tag with a " " label. wrap_inline
        # would return the bare space and lose the link.
        element = Markbridge::AST::Url.new(href: "https://example.com")
        element << Markbridge::AST::Text.new(" ")

        expect(tag.render(element, interface)).to eq("https://example.com")
      end

      it "keeps edge whitespace of the label outside the link markers" do
        element = Markbridge::AST::Url.new(href: "https://example.com")
        element << Markbridge::AST::Text.new(" label ")

        expect(tag.render(element, interface)).to eq(" [label](https://example.com) ")
      end

      it "detects bareness on the AST, unaffected by Markdown escaping of the label" do
        # The rendered label would be "https://example.com/a\_b" — comparing
        # rendered text against the href would miss this bare URL.
        element = Markbridge::AST::Url.new(href: "https://example.com/a_b")
        element << Markbridge::AST::Text.new("https://example.com/a_b")

        expect(tag.render(element, interface)).to eq("https://example.com/a_b")
      end

      it "still renders a Markdown link when the text differs from the href" do
        element = Markbridge::AST::Url.new(href: "https://example.com")
        element << Markbridge::AST::Text.new("here")

        expect(tag.render(element, interface)).to eq("[here](https://example.com)")
      end

      it "is not bare when more children follow the href-equal text" do
        # The label is "href + formatting", not a bare URL — dropping the
        # extra children would lose content.
        element = Markbridge::AST::Url.new(href: "https://example.com")
        element << Markbridge::AST::Text.new("https://example.com")
        italic = Markbridge::AST::Italic.new << Markbridge::AST::Text.new("really")
        element << italic

        expect(tag.render(element, interface)).to eq(
          "[https://example.com*really*](https://example.com)",
        )
      end

      context "when text stands right next to the URL" do
        # Renders a bare URL with the given neighbors inside a paragraph,
        # so the tag can see its siblings.
        def render_between(before, after)
          paragraph = Markbridge::AST::Paragraph.new
          paragraph << Markbridge::AST::Text.new(before) if before
          url = Markbridge::AST::Url.new(href: "https://example.com")
          url << Markbridge::AST::Text.new("https://example.com")
          paragraph << url
          paragraph << after if after

          context = Markbridge::Renderers::Discourse::RenderContext.new([paragraph])
          tag.render(
            url,
            Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context),
          )
        end

        it "writes a link with the URL as text when a word ends right in front of the URL" do
          expect(render_between("see", nil)).to eq("[https://example.com](https://example.com)")
        end

        it "writes a link with the URL as text when text starts right after the URL" do
          expect(render_between(nil, Markbridge::AST::Text.new("now"))).to eq(
            "[https://example.com](https://example.com)",
          )
        end

        it "escapes the destination of a glued bare URL like any other" do
          paragraph = Markbridge::AST::Paragraph.new
          paragraph << Markbridge::AST::Text.new("see")
          url = Markbridge::AST::Url.new(href: "Main (Page)")
          url << Markbridge::AST::Text.new("Main (Page)")
          paragraph << url
          context = Markbridge::Renderers::Discourse::RenderContext.new([paragraph])
          interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

          expect(tag.render(url, interface)).to eq("[Main (Page)](<Main \\(Page\\)>)")
        end

        it "links a relative href glued to text the same way" do
          paragraph = Markbridge::AST::Paragraph.new
          paragraph << Markbridge::AST::Text.new("see")
          url = Markbridge::AST::Url.new(href: "/t/5")
          url << Markbridge::AST::Text.new("/t/5")
          paragraph << url
          context = Markbridge::Renderers::Discourse::RenderContext.new([paragraph])
          interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

          expect(tag.render(url, interface)).to eq("[/t/5](/t/5)")
        end

        it "uses the escaped text as the label, not the raw href" do
          # A raw `]` would end the label early, a raw `_` could start
          # emphasis in it.
          paragraph = Markbridge::AST::Paragraph.new
          paragraph << Markbridge::AST::Text.new("see")
          url = Markbridge::AST::Url.new(href: "https://example.com/a]b_c")
          url << Markbridge::AST::Text.new("https://example.com/a]b_c")
          paragraph << url
          context = Markbridge::Renderers::Discourse::RenderContext.new([paragraph])
          interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

          expect(tag.render(url, interface)).to eq(
            "[https://example.com/a\\]b\\_c](https://example.com/a]b_c)",
          )
        end

        it "renders the href as the label when the link has no text" do
          # The `]` is only escaped for text under the link, so the href
          # has to be rendered as a child of the link, not on its own.
          paragraph = Markbridge::AST::Paragraph.new
          paragraph << Markbridge::AST::Text.new("see")
          url = Markbridge::AST::Url.new(href: "https://example.com/a]b")
          paragraph << url
          context = Markbridge::Renderers::Discourse::RenderContext.new([paragraph])
          interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

          expect(tag.render(url, interface)).to eq(
            "[https://example.com/a\\]b](https://example.com/a]b)",
          )
        end

        it "renders the href as the label when the label renders to nothing" do
          paragraph = Markbridge::AST::Paragraph.new
          url = Markbridge::AST::Url.new(href: "https://example.com/a]b")
          url << Markbridge::AST::Bold.new
          paragraph << url
          paragraph << Markbridge::AST::Text.new("now")
          context = Markbridge::Renderers::Discourse::RenderContext.new([paragraph])
          interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

          expect(tag.render(url, interface)).to eq(
            "[https://example.com/a\\]b](https://example.com/a]b)",
          )
        end

        it "keeps the plain href when whitespace stands in front of the URL" do
          expect(render_between("see ", nil)).to eq("https://example.com")
        end

        it "keeps the plain href when whitespace follows the URL" do
          expect(render_between(nil, Markbridge::AST::Text.new(" now"))).to eq(
            "https://example.com",
          )
        end

        it "keeps the plain href when a sentence ends after the URL" do
          # Linkify leaves the punctuation out of the link.
          expect(render_between("See ", Markbridge::AST::Text.new("."))).to eq(
            "https://example.com",
          )
        end

        it "writes a link when inline code follows the URL" do
          # Otherwise the autolink takes the backticks into the URL.
          code = Markbridge::AST::Code.new << Markbridge::AST::Text.new("x")

          expect(render_between("see ", code)).to eq("[https://example.com](https://example.com)")
        end

        it "writes a link when emphasis stands in front of the URL" do
          paragraph = Markbridge::AST::Paragraph.new
          paragraph << (Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x"))
          url = Markbridge::AST::Url.new(href: "https://example.com")
          url << Markbridge::AST::Text.new("https://example.com")
          paragraph << url
          context = Markbridge::Renderers::Discourse::RenderContext.new([paragraph])
          interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

          expect(tag.render(url, interface)).to eq("[https://example.com](https://example.com)")
        end

        it "decides by the edge of Markdown text next to the URL" do
          expect(render_between(nil, Markbridge::AST::MarkdownText.new("**x**"))).to eq(
            "[https://example.com](https://example.com)",
          )
          expect(render_between(nil, Markbridge::AST::MarkdownText.new(" **x**"))).to eq(
            "https://example.com",
          )
        end

        it "keeps the plain href next to a subclass of a block" do
          quote_class = Class.new(Markbridge::AST::Quote)

          expect(render_between(nil, quote_class.new << Markbridge::AST::Text.new("q"))).to eq(
            "https://example.com",
          )
        end

        it "keeps the plain href when a line break follows the URL" do
          expect(render_between(nil, Markbridge::AST::LineBreak.new)).to eq("https://example.com")
        end

        it "keeps the plain href next to a block" do
          [
            Markbridge::AST::Paragraph.new << Markbridge::AST::Text.new("p"),
            Markbridge::AST::Quote.new << Markbridge::AST::Text.new("q"),
            Markbridge::AST::Heading.new(level: 2) << Markbridge::AST::Text.new("h"),
            Markbridge::AST::Align.new(alignment: "center") << Markbridge::AST::Text.new("a"),
            Markbridge::AST::Details.new << Markbridge::AST::Text.new("d"),
            Markbridge::AST::Table.new,
            Markbridge::AST::Poll.new,
            Markbridge::AST::Event.new(name: "e", starts_at: "2026-01-01"),
            Markbridge::AST::List.new,
            Markbridge::AST::HorizontalRule.new,
          ].each do |block|
            expect(render_between(nil, block)).to eq("https://example.com"), block.class.name
          end
        end

        it "keeps the plain href when punctuation and whitespace follow the URL" do
          %w[, : ! ? ... ?!].each do |punctuation|
            expect(render_between(nil, Markbridge::AST::Text.new("#{punctuation} next"))).to eq(
              "https://example.com",
            )
          end
        end

        it "keeps the plain href inside parentheses" do
          expect(render_between("(see ", Markbridge::AST::Text.new(")."))).to eq(
            "https://example.com",
          )
        end

        it "keeps the plain href when an opening parenthesis stands in front of the URL" do
          expect(render_between("(", nil)).to eq("https://example.com")
        end

        it "writes a link when text follows the punctuation after the URL" do
          expect(render_between(nil, Markbridge::AST::Text.new(".com"))).to eq(
            "[https://example.com](https://example.com)",
          )
        end

        it "writes a link when a semicolon follows the URL" do
          # cmark-gfm keeps a semicolon in the link.
          expect(render_between(nil, Markbridge::AST::Text.new(";"))).to eq(
            "[https://example.com](https://example.com)",
          )
        end

        it "writes a link when a quote stands in front of the URL" do
          expect(render_between("\"", nil)).to eq("[https://example.com](https://example.com)")
        end

        it "writes a link when a ) follows a URL that has parentheses of its own" do
          # Both parsers keep the ) in the link, it closes the one in the href.
          paragraph = Markbridge::AST::Paragraph.new
          url = Markbridge::AST::Url.new(href: "https://example.com/a(b")
          url << Markbridge::AST::Text.new("https://example.com/a(b")
          paragraph << url
          paragraph << Markbridge::AST::Text.new(")")
          context = Markbridge::Renderers::Discourse::RenderContext.new([paragraph])
          interface = Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context)

          expect(tag.render(url, interface)).to eq(
            "[https://example.com/a(b](https://example.com/a\\(b)",
          )
        end

        it "keeps the plain href when the URL has no neighbors" do
          expect(render_between(nil, nil)).to eq("https://example.com")
        end

        it "writes a link when emphasis follows the URL" do
          # cmark-gfm takes `**x` into a bare URL; markdown-it does not.
          bold = Markbridge::AST::Bold.new
          bold << Markbridge::AST::Text.new("x")

          expect(render_between(nil, bold)).to eq("[https://example.com](https://example.com)")
        end
      end

      it "keeps the <a> form for text-less links in html_mode" do
        html_context = Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true)
        html_interface =
          Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, html_context)
        element = Markbridge::AST::Url.new(href: "https://example.com")

        expect(tag.render(element, html_interface)).to eq('<a href="https://example.com"></a>')
      end
    end

    context "with relative hrefs" do
      it "links relative paths" do
        element = Markbridge::AST::Url.new(href: "/t/5")
        element << Markbridge::AST::Text.new("here")

        expect(tag.render(element, interface)).to eq("[here](/t/5)")
      end

      it "links anchors" do
        element = Markbridge::AST::Url.new(href: "#section")
        element << Markbridge::AST::Text.new("jump")

        expect(tag.render(element, interface)).to eq("[jump](#section)")
      end

      it "links protocol-relative URLs" do
        element = Markbridge::AST::Url.new(href: "//example.com/x")
        element << Markbridge::AST::Text.new("there")

        expect(tag.render(element, interface)).to eq("[there](//example.com/x)")
      end

      it "wraps whitespace-containing destinations in <> (CommonMark form)" do
        element = Markbridge::AST::Url.new(href: "Main Page")
        element << Markbridge::AST::Text.new("Home")

        expect(tag.render(element, interface)).to eq("[Home](<Main Page>)")
      end

      it "still drops scheme-like unknown protocols (data:)" do
        element = Markbridge::AST::Url.new(href: "data:text/html,x")
        element << Markbridge::AST::Text.new("Bad")

        expect(tag.render(element, interface)).to eq("Bad")
      end

      it "drops empty hrefs" do
        element = Markbridge::AST::Url.new(href: "")
        element << Markbridge::AST::Text.new("text")

        expect(tag.render(element, interface)).to eq("text")
      end
    end
  end
end
