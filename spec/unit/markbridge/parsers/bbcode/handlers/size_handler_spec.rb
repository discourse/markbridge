# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::SizeHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(attrs: {})
    Markbridge::Parsers::BBCode::TagStartToken.new(tag: "size", attrs:, pos: 0, source: "[size]")
  end

  describe "#initialize" do
    it "exposes AST::Size as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Size)
    end
  end

  describe "#auto_closeable?" do
    it "is true" do
      expect(handler.auto_closeable?).to be true
    end
  end

  describe "#on_open" do
    it "pushes a Size element using attrs[:size]" do
      handler.on_open(token: tag_start(attrs: { size: "20" }), context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Size)
      expect(context.current.size).to eq("20")
    end

    it "falls back to attrs[:option] when :size is missing" do
      handler.on_open(token: tag_start(attrs: { option: "large" }), context:, registry:)

      expect(context.current.size).to eq("large")
    end

    it "prefers attrs[:size] over attrs[:option]" do
      handler.on_open(token: tag_start(attrs: { size: "20", option: "large" }), context:, registry:)

      expect(context.current.size).to eq("20")
    end

    it "pushes with nil size when neither is present" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current.size).to be_nil
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
