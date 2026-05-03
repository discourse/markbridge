# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::ColorHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(attrs: {})
    Markbridge::Parsers::BBCode::TagStartToken.new(tag: "color", attrs:, pos: 0, source: "[color]")
  end

  describe "#initialize" do
    it "exposes AST::Color as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Color)
    end
  end

  describe "#auto_closeable?" do
    it "is true" do
      expect(handler.auto_closeable?).to be true
    end
  end

  describe "#on_open" do
    it "pushes a Color element using attrs[:color]" do
      handler.on_open(token: tag_start(attrs: { color: "red" }), context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Color)
      expect(context.current.color).to eq("red")
    end

    it "falls back to attrs[:option] when :color is missing" do
      handler.on_open(token: tag_start(attrs: { option: "#ff0000" }), context:, registry:)

      expect(context.current.color).to eq("#ff0000")
    end

    it "prefers attrs[:color] over attrs[:option]" do
      handler.on_open(
        token: tag_start(attrs: { color: "blue", option: "red" }),
        context:,
        registry:,
      )

      expect(context.current.color).to eq("blue")
    end

    it "pushes with nil color when neither is present" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Color)
      expect(context.current.color).to be_nil
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
