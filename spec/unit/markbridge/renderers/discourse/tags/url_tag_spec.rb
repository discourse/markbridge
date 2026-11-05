# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UrlTag do
  include_context "with a renderer tag"
  let(:tokens) { Markbridge::Renderers::Discourse::Inline::Tokens }

  def link(href, text = "Example")
    element = Markbridge::AST::Url.new(href:)
    element << Markbridge::AST::Text.new(text) if text
    element
  end

  def bare(href = "https://example.com")
    link(href, href)
  end

  describe "#render" do
    it "returns a link token pair around the children" do
      expect(tag.render(link("https://example.com"), interface)).to eq(
        [tokens.link_open("https://example.com"), "Example", tokens.link_close],
      )
    end

    it "returns a bare URL token when the only text equals the href, or there is no text" do
      # A bare URL autolinks (and can onebox) in Discourse; a
      # [url](url) Markdown link does not.
      expect(tag.render(bare, interface)).to eq([tokens.bare_url("https://example.com")])
      expect(tag.render(link("https://example.com", nil), interface)).to eq(
        [tokens.bare_url("https://example.com")],
      )
    end

    it "returns a bare URL token when the label renders to nothing, or to whitespace" do
      # Not bare on the AST (a non-Text child exists), but the child
      # produces no output — `[](url)` would show nothing. The HTML
      # parser keeps a space at an inline element's edge, so
      # `<a href="…"> </a>` reaches the tag with a " " label.
      empty = link("https://example.com", nil) << Markbridge::AST::Bold.new

      expect(tag.render(empty, interface)).to eq([tokens.bare_url("https://example.com")])
      expect(tag.render(link("https://example.com", " "), interface)).to eq(
        [tokens.bare_url("https://example.com")],
      )
    end

    it "detects bareness on the AST, unaffected by Markdown escaping of the label" do
      # The rendered label would be "https://example.com/a\_b" — comparing
      # rendered text against the href would miss this bare URL.
      expect(tag.render(bare("https://example.com/a_b"), interface)).to eq(
        [tokens.bare_url("https://example.com/a_b")],
      )
    end

    it "is not bare when more children follow the href-equal text" do
      # The label is "href + formatting", not a bare URL — dropping the
      # extra children would lose content.
      element = bare
      element << (Markbridge::AST::Italic.new << Markbridge::AST::Text.new("really"))

      expect(rendered(element)).to eq("[https://example.com*really*](https://example.com)")
    end

    it "returns the children alone for an href without a scheme the renderer links" do
      expect(tag.render(link("javascript:alert(1)"), interface)).to eq(["Example"])
      expect(tag.render(link("data:text/html,x"), interface)).to eq(["Example"])
      expect(tag.render(link(nil), interface)).to eq(["Example"])
      expect(tag.render(link(""), interface)).to eq(["Example"])
      expect(tag.render(link("xhttps://example.com"), interface)).to eq(["Example"])
    end

    it "links http, https, ftp, ftps and mailto, whatever the case of the scheme" do
      %w[
        http://e.com
        https://e.com
        ftp://e.com
        ftps://e.com
        mailto:a@e.com
        HTTPS://e.com
      ].each { |href| expect(rendered(link(href))).to eq("[Example](#{href})") }
    end

    it "links relative paths, anchors and protocol-relative URLs" do
      expect(rendered(link("/t/5"))).to eq("[Example](/t/5)")
      expect(rendered(link("#section"))).to eq("[Example](#section)")
      expect(rendered(link("//example.com/x"))).to eq("[Example](//example.com/x)")
    end

    it "escapes every ] in the label so none ends the link early" do
      expect(rendered(link("https://example.com", "[A] and [B]"))).to eq(
        "[\\[A\\] and \\[B\\]](https://example.com)",
      )
    end

    it "keeps structural ] in child markdown, for example an image's empty alt" do
      element = link("https://example.com", nil)
      element << Markbridge::AST::Image.new(src: "x.png")

      expect(rendered(element)).to eq("[![](x.png)](https://example.com)")
    end

    let(:element_class) { Markbridge::AST::Url }
    let(:element_factory) { Markbridge::AST::Url.new(href: "https://example.com") }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { html_context }

      it "renders as <a href> for valid hrefs, also without text" do
        expect(rendered(link("https://example.com"))).to eq(
          %(<a href="https://example.com">Example</a>),
        )
        expect(rendered(link("https://example.com", nil))).to eq(
          %(<a href="https://example.com">https://example.com</a>),
        )
      end

      it "attribute-escapes the href" do
        expect(rendered(link(%(https://example.com/?a=1&b="x")))).to eq(
          %(<a href="https://example.com/?a=1&amp;b=&quot;x&quot;">Example</a>),
        )
      end

      it "falls back to plain text for invalid schemes" do
        expect(rendered(link("javascript:alert(1)"))).to eq("Example")
      end
    end

    # The serializer decides from the neighbors whether a bare URL can
    # stay bare, and its spec has the forms. These two examples check
    # that the token reaches it through the renderer.
    context "with a bare URL next to other content" do
      def render_between(before, after, href: "https://example.com")
        paragraph = Markbridge::AST::Document.new
        paragraph << Markbridge::AST::Text.new(before) if before
        paragraph << bare(href)
        paragraph << after if after
        renderer.render(paragraph)
      end

      it "keeps the plain href with whitespace around it, or with no neighbors" do
        expect(render_between("see ", Markbridge::AST::Text.new(" now"))).to eq(
          "see https://example.com now",
        )
        expect(render_between(nil, nil)).to eq("https://example.com")
        expect(render_between(nil, Markbridge::AST::LineBreak.new)).to eq("https://example.com\n")
      end

      it "writes a link with the URL as text when text is glued to it" do
        expect(render_between("see", nil)).to eq("see[https://example.com](https://example.com)")
        expect(render_between(nil, Markbridge::AST::Text.new("now"))).to eq(
          "[https://example.com](https://example.com)now",
        )
      end
    end
  end
end
