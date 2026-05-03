# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::SimpleHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:element_class) { Markbridge::AST::Bold }
  let(:handler) { described_class.new(element_class) }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(tag: "b", source: "[b]")
    Markbridge::Parsers::BBCode::TagStartToken.new(tag:, attrs: {}, pos: 0, source:)
  end

  describe "#initialize" do
    it "accepts an element class" do
      expect { described_class.new(Markbridge::AST::Bold) }.not_to raise_error
    end

    it "exposes the element_class via reader" do
      expect(described_class.new(Markbridge::AST::Italic).element_class).to eq(
        Markbridge::AST::Italic,
      )
    end

    it "defaults auto_closeable? to false" do
      expect(described_class.new(Markbridge::AST::Bold).auto_closeable?).to be false
    end

    it "stores the auto_closeable: flag for reporting" do
      expect(
        described_class.new(Markbridge::AST::Bold, auto_closeable: true).auto_closeable?,
      ).to be(true)
    end
  end

  describe "#on_open" do
    it "creates element and pushes to context" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Bold)
    end

    it "creates the correct element class" do
      italic_handler = described_class.new(Markbridge::AST::Italic)

      italic_handler.on_open(token: tag_start(tag: "i", source: "[i]"), context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Italic)
    end

    it "forwards the token to context.push for graceful-degradation bookkeeping" do
      # Fill the stack to MAX_DEPTH so the next push has to fall back via the
      # token path (context.push with a token: records it via
      # depth_exceeded_count instead of raising).
      max = Markbridge::Parsers::BBCode::ParserState::MAX_DEPTH
      max.times { context.push(Markbridge::AST::Italic.new) }

      expect { handler.on_open(token: tag_start(source: "[b]"), context:, registry:) }.to change(
        context,
        :depth_exceeded_count,
      ).by(1)
    end
  end

  describe "#auto_closeable?" do
    it "returns false when not configured as auto_closeable" do
      expect(described_class.new(Markbridge::AST::Bold).auto_closeable?).to be false
    end

    it "returns true when configured as auto_closeable" do
      expect(
        described_class.new(Markbridge::AST::Bold, auto_closeable: true).auto_closeable?,
      ).to be(true)
    end
  end
end
