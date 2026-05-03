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
