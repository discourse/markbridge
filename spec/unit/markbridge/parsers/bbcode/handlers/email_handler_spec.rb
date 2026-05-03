# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::EmailHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(attrs: {})
    Markbridge::Parsers::BBCode::TagStartToken.new(tag: "email", attrs:, pos: 0, source: "[email]")
  end

  describe "#initialize" do
    it "exposes AST::Email as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Email)
    end
  end

  describe "#on_open" do
    it "pushes an Email element using attrs[:email]" do
      handler.on_open(token: tag_start(attrs: { email: "[email protected]" }), context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Email)
      expect(context.current.address).to eq("[email protected]")
    end

    it "falls back to attrs[:address] when :email is missing" do
      handler.on_open(
        token: tag_start(attrs: { address: "[email protected]" }),
        context:,
        registry:,
      )

      expect(context.current.address).to eq("[email protected]")
    end

    it "falls back to attrs[:option] when :email and :address are missing" do
      handler.on_open(token: tag_start(attrs: { option: "[email protected]" }), context:, registry:)

      expect(context.current.address).to eq("[email protected]")
    end

    it "prefers :email over :address" do
      handler.on_open(
        token: tag_start(attrs: { email: "[email protected]", address: "[email protected]" }),
        context:,
        registry:,
      )

      expect(context.current.address).to eq("[email protected]")
    end

    it "prefers :address over :option" do
      handler.on_open(
        token: tag_start(attrs: { address: "[email protected]", option: "[email protected]" }),
        context:,
        registry:,
      )

      expect(context.current.address).to eq("[email protected]")
    end

    it "pushes with nil address when none are present" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current.address).to be_nil
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
