# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::QuoteHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(attrs: {})
    Markbridge::Parsers::BBCode::TagStartToken.new(tag: "quote", attrs:, pos: 0, source: "[quote]")
  end

  describe "#initialize" do
    it "exposes AST::Quote as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Quote)
    end
  end

  describe "#on_open" do
    it "creates a Quote with no attribution when attrs are empty" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Quote)
      expect(context.current.author).to be_nil
      expect(context.current.username).to be_nil
      expect(context.current.post).to be_nil
      expect(context.current.topic).to be_nil
    end

    it "uses a bare :option as the author but does not populate username/post/topic" do
      handler.on_open(token: tag_start(attrs: { option: "John" }), context:, registry:)

      quote = context.current
      expect(quote.author).to eq("John")
      expect(quote.username).to be_nil
      expect(quote.post).to be_nil
      expect(quote.topic).to be_nil
    end

    it "uses the :author attribute when no :option is set" do
      handler.on_open(token: tag_start(attrs: { author: "Jane" }), context:, registry:)

      expect(context.current.author).to eq("Jane")
    end

    it "prefers :option over :author when both are present" do
      handler.on_open(
        token: tag_start(attrs: { option: "FromOption", author: "FromAuthor" }),
        context:,
        registry:,
      )

      expect(context.current.author).to eq("FromOption")
    end

    context "with the Discourse option format" do
      it "parses username, post and topic from 'user, post:N, topic:M'" do
        handler.on_open(
          token: tag_start(attrs: { option: "john, post:123, topic:456" }),
          context:,
          registry:,
        )

        quote = context.current
        expect(quote.author).to eq("john")
        expect(quote.username).to eq("john")
        expect(quote.post).to eq("123")
        expect(quote.topic).to eq("456")
      end

      it "accepts post-only (no topic) parts after the username" do
        handler.on_open(token: tag_start(attrs: { option: "john, post:7" }), context:, registry:)

        quote = context.current
        expect(quote.post).to eq("7")
        expect(quote.topic).to be_nil
      end

      it "accepts Discourse parts with no space after the comma" do
        handler.on_open(
          token: tag_start(attrs: { option: "john,post:42,topic:9" }),
          context:,
          registry:,
        )

        expect(context.current.post).to eq("42")
        expect(context.current.topic).to eq("9")
      end

      it "accepts Discourse parts with extra whitespace after the comma" do
        handler.on_open(
          token: tag_start(attrs: { option: "john,   post:42,   topic:9" }),
          context:,
          registry:,
        )

        expect(context.current.post).to eq("42")
        expect(context.current.topic).to eq("9")
      end

      it "strips surrounding whitespace from the parsed username" do
        handler.on_open(
          token: tag_start(attrs: { option: "  john  , post:42" }),
          context:,
          registry:,
        )

        expect(context.current.username).to eq("john")
      end

      it "ignores unrecognised parts after the username" do
        handler.on_open(
          token: tag_start(attrs: { option: "john, post:7, reply:3" }),
          context:,
          registry:,
        )

        expect(context.current.post).to eq("7")
        expect(context.current.topic).to be_nil
      end
    end

    context "with both :option and explicit attributes" do
      it "prefers explicit :post over option-parsed post" do
        handler.on_open(
          token: tag_start(attrs: { option: "john, post:1, topic:2", post: "99" }),
          context:,
          registry:,
        )

        expect(context.current.post).to eq("99")
      end

      it "prefers explicit :topic over option-parsed topic" do
        handler.on_open(
          token: tag_start(attrs: { option: "john, post:1, topic:2", topic: "88" }),
          context:,
          registry:,
        )

        expect(context.current.topic).to eq("88")
      end

      it "prefers explicit :username over option-parsed username" do
        handler.on_open(
          token: tag_start(attrs: { option: "john, post:1, topic:2", username: "bob" }),
          context:,
          registry:,
        )

        expect(context.current.username).to eq("bob")
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
