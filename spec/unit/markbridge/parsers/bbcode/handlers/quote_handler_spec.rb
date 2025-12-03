# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::QuoteHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  describe "#on_open" do
    it "creates Quote element without attribution" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "quote",
          attrs: {
          },
          pos: 0,
          source: "[quote]",
        )

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Quote)
      expect(context.current.author).to be_nil
    end

    it "creates Quote element with author from option" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "quote",
          attrs: {
            option: "John",
          },
          pos: 0,
          source: "[quote=John]",
        )

      handler.on_open(token:, context:, registry:)

      quote = context.current
      expect(quote).to be_a(Markbridge::AST::Quote)
      expect(quote.author).to eq("John")
    end

    it "creates Quote element with author from author attribute" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "quote",
          attrs: {
            author: "Jane",
          },
          pos: 0,
          source: "[quote author=Jane]",
        )

      handler.on_open(token:, context:, registry:)

      quote = context.current
      expect(quote.author).to eq("Jane")
    end

    it "parses Discourse-style quote with post and topic" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "quote",
          attrs: {
            option: "john, post:123, topic:456",
          },
          pos: 0,
          source: "[quote=\"john, post:123, topic:456\"]",
        )

      handler.on_open(token:, context:, registry:)

      quote = context.current
      expect(quote.author).to eq("john")
      expect(quote.username).to eq("john")
      expect(quote.post).to eq("123")
      expect(quote.topic).to eq("456")
    end

    it "handles explicit username, post, topic attributes" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "quote",
          attrs: {
            username: "bob",
            post: "789",
            topic: "012",
          },
          pos: 0,
          source: "[quote username=bob post=789 topic=012]",
        )

      handler.on_open(token:, context:, registry:)

      quote = context.current
      expect(quote.username).to eq("bob")
      expect(quote.post).to eq("789")
      expect(quote.topic).to eq("012")
    end
  end
end
