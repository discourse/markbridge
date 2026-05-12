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
  end
end
