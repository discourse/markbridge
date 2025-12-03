# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::UrlHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:handler) { described_class.new }

  describe "#on_open" do
    it "creates Url element with href from option attribute" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "url",
          attrs: {
            option: "https://example.com",
          },
          pos: 0,
          source: "[url=https://example.com]",
        )
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Url)
      expect(context.current.href).to eq("https://example.com")
    end

    it "creates Url element with href from href attribute" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "url",
          attrs: {
            href: "https://google.com",
          },
          pos: 0,
          source: "[url href=https://google.com]",
        )
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      handler.on_open(token:, context:, registry:)

      expect(context.current.href).to eq("https://google.com")
    end

    it "creates Url element with href from url attribute" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "url",
          attrs: {
            url: "https://github.com",
          },
          pos: 0,
          source: "[url url=https://github.com]",
        )
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      handler.on_open(token:, context:, registry:)

      expect(context.current.href).to eq("https://github.com")
    end

    it "prefers href over url and option" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "url",
          attrs: {
            href: "https://a.com",
            url: "https://b.com",
            option: "https://c.com",
          },
          pos: 0,
          source: "[url href=https://a.com url=https://b.com]",
        )
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      handler.on_open(token:, context:, registry:)

      expect(context.current.href).to eq("https://a.com")
    end

    it "creates Url element with nil href when no attributes" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "url",
          attrs: {
          },
          pos: 0,
          source: "[url]",
        )
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      handler.on_open(token:, context:, registry:)

      expect(context.current.href).to be_nil
    end
  end
end
