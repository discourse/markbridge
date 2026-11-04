# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::UrlHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(attrs: {})
    Markbridge::Parsers::BBCode::TagStartToken.new(tag: "url", attrs:, pos: 0, source: "[url]")
  end

  describe "#initialize" do
    it "exposes AST::Url as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Url)
    end
  end

  describe "#on_open" do
    it "pushes a Url element using attrs[:href]" do
      handler.on_open(token: tag_start(attrs: { href: "https://example.com" }), context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Url)
      expect(context.current.href).to eq("https://example.com")
    end

    it "falls back to attrs[:url] when :href is missing" do
      handler.on_open(token: tag_start(attrs: { url: "https://example.com" }), context:, registry:)

      expect(context.current.href).to eq("https://example.com")
    end

    it "falls back to attrs[:option] when :href and :url are missing" do
      handler.on_open(
        token: tag_start(attrs: { option: "https://example.com" }),
        context:,
        registry:,
      )

      expect(context.current.href).to eq("https://example.com")
    end

    it "prefers :href over :url" do
      handler.on_open(
        token: tag_start(attrs: { href: "https://a.com", url: "https://b.com" }),
        context:,
        registry:,
      )

      expect(context.current.href).to eq("https://a.com")
    end

    it "prefers :url over :option" do
      handler.on_open(
        token: tag_start(attrs: { url: "https://a.com", option: "https://b.com" }),
        context:,
        registry:,
      )

      expect(context.current.href).to eq("https://a.com")
    end

    it "pushes with nil href when no attribute is present" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current.href).to be_nil
    end

    context "when the href is the text of the tag" do
      def tokens(source)
        Markbridge::Parsers::BBCode::PeekableEnumerator.new(
          Markbridge::Parsers::BBCode::Scanner.new(source),
        )
      end

      def open_with(source, tag: "url")
        token =
          Markbridge::Parsers::BBCode::TagStartToken.new(
            tag:,
            attrs: {
            },
            pos: 0,
            source: "[#{tag}]",
          )
        rest = tokens(source)
        handler.on_open(token:, context:, registry:, tokens: rest)
        rest
      end

      it "adds a Url with the text as href and as its text" do
        rest = open_with("https://example.com/a_b[/url] after")

        url = document.children.first
        expect(url).to be_a(Markbridge::AST::Url)
        expect(url.href).to eq("https://example.com/a_b")
        expect(url.children.map(&:text)).to eq(["https://example.com/a_b"])
        expect(context.current).to eq(document)
        expect(rest.next).to match_text_token(" after")
      end

      it "drops whitespace around the text" do
        open_with(" https://example.com \n[/url]")

        expect(document.children.first.href).to eq("https://example.com")
        expect(document.children.first.children.map(&:text)).to eq(["https://example.com"])
      end

      it "matches the closing tag of the alias it was opened with" do
        open_with("https://example.com[/link]", tag: "link")

        expect(document.children.first.href).to eq("https://example.com")
      end

      it "pushes with nil href when the closing tag is another tag" do
        rest = open_with("https://example.com[/link]")

        expect(context.current.href).to be_nil
        expect(rest.next).to match_text_token("https://example.com")
      end

      it "pushes with nil href when the text holds a tag" do
        rest = open_with("[b]https://example.com[/b][/url]")

        expect(context.current.href).to be_nil
        expect(rest.next).to match_tag_start("b")
      end

      it "pushes with nil href when a tag comes before the closing tag" do
        rest = open_with("[i][/url]")

        expect(context.current.href).to be_nil
        expect(rest.next).to match_tag_start("i")
      end

      it "pushes with nil href when another url tag opens after the text" do
        rest = open_with("https://a.example[url]https://b.example[/url][/url]")

        expect(context.current.href).to be_nil
        expect(rest.next).to match_text_token("https://a.example")
      end

      it "pushes with nil href when the tag is not closed" do
        open_with("https://example.com")

        expect(context.current.href).to be_nil
      end

      it "pushes with nil href when the text is only whitespace" do
        rest = open_with("  [/url]")

        expect(context.current.href).to be_nil
        expect(rest.next).to match_text_token("  ")
      end
    end

    it "forwards the token to context.push for graceful-degradation bookkeeping" do
      max = Markbridge::Parsers::BBCode::ParserState::MAX_DEPTH
      max.times { context.push(Markbridge::AST::Italic.new) }

      expect { handler.on_open(token: tag_start, context:, registry:) }.to change(
        context,
        :depth_exceeded_count,
      ).by(1)
    end
  end
end
