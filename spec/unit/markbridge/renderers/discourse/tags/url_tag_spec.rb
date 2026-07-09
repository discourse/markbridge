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
