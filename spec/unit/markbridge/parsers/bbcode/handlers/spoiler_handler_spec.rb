# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::SpoilerHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(attrs: {})
    Markbridge::Parsers::BBCode::TagStartToken.new(
      tag: "spoiler",
      attrs:,
      pos: 0,
      source: "[spoiler]",
    )
  end

  describe "#initialize" do
    it "exposes AST::Spoiler as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Spoiler)
    end
  end

  describe "#on_open" do
    it "pushes a Spoiler element using attrs[:title]" do
      handler.on_open(token: tag_start(attrs: { title: "Click me" }), context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Spoiler)
      expect(context.current.title).to eq("Click me")
    end

    it "falls back to attrs[:option] when :title is missing" do
      handler.on_open(token: tag_start(attrs: { option: "reveal" }), context:, registry:)

      expect(context.current.title).to eq("reveal")
    end

    it "prefers attrs[:title] over attrs[:option]" do
      handler.on_open(token: tag_start(attrs: { title: "A", option: "B" }), context:, registry:)

      expect(context.current.title).to eq("A")
    end

    it "pushes with nil title when neither is present" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current.title).to be_nil
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
