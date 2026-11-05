# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UrlTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }
  let(:tokens) { Markbridge::Renderers::Discourse::Inline::Tokens }

  # The tag returns tokens, the renderer writes them.
  def rendered(element)
    renderer.serialize(tag.render(element, interface), context)
  end

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

    it "escapes the destination and wraps one with whitespace in angle brackets" do
      expect(rendered(link("https://example.com/a(b)c)"))).to eq(
        "[Example](https://example.com/a\\(b\\)c\\))",
      )
      expect(rendered(link("https://example.com/a\\"))).to eq(
        "[Example](https://example.com/a\\\\)",
      )
      expect(rendered(link("Main (Page)"))).to eq("[Example](<Main \\(Page\\)>)")
      expect(rendered(link("https://example.com/a?b=c&d=e"))).to eq(
        "[Example](https://example.com/a?b=c&d=e)",
      )
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

    it "keeps edge whitespace of the label outside the link markers" do
      expect(rendered(link("https://example.com", " label "))).to eq(
        " [label](https://example.com) ",
      )
    end

    let(:element_class) { Markbridge::AST::Url }
    let(:element_factory) { Markbridge::AST::Url.new(href: "https://example.com") }
    it_behaves_like "a tag that propagates parent context"

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

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
    # stay bare. These examples render the whole paragraph.
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

      it "escapes the label of a glued bare URL like a link label and the destination like one" do
        expect(render_between("see", nil, href: "https://example.com/a]b_c")).to eq(
          "see[https://example.com/a\\]b\\_c](https://example.com/a]b_c)",
        )
        expect(render_between("see", nil, href: "/a (b)")).to eq("see[/a (b)](</a \\(b\\)>)")
      end

      it "writes a link when inline code or emphasis stands next to the URL" do
        code = Markbridge::AST::Code.new << Markbridge::AST::Text.new("x")
        bold = Markbridge::AST::Bold.new << Markbridge::AST::Text.new("x")

        expect(render_between("see ", code)).to eq(
          "see [https://example.com](https://example.com)`x`",
        )
        expect(render_between(nil, bold)).to eq("[https://example.com](https://example.com)**x**")
      end

      it "keeps the plain href when sentence punctuation and whitespace follow it" do
        %w[. , ! ? ... ). ),].each do |punctuation|
          expect(render_between(nil, Markbridge::AST::Text.new("#{punctuation} next"))).to eq(
            "https://example.com#{punctuation} next",
          )
        end
      end

      it "writes a link when punctuation follows that linkify keeps in the link" do
        %w[: .) ?! ., ;].each do |punctuation|
          expect(render_between(nil, Markbridge::AST::Text.new("#{punctuation} next"))).to eq(
            "[https://example.com](https://example.com)#{punctuation} next",
          )
        end
      end

      it "keeps the plain href inside parentheses, and links it when the href has a parenthesis" do
        expect(render_between("(", Markbridge::AST::Text.new(")."))).to eq("(https://example.com).")
        expect(
          render_between(nil, Markbridge::AST::Text.new(")"), href: "https://example.com/a(b"),
        ).to eq("[https://example.com/a(b](https://example.com/a\\(b))")
      end

      it "writes a link for an href that linkify does not link on its own, whatever the neighbors" do
        expect(render_between("see ", Markbridge::AST::Text.new(" now"), href: "/t/5")).to eq(
          "see [/t/5](/t/5) now",
        )
        expect(render_between(nil, nil, href: "#top")).to eq("[#top](#top)")
      end
    end
  end
end
