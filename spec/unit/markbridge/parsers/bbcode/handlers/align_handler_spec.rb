# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::AlignHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(tag: "center")
    Markbridge::Parsers::BBCode::TagStartToken.new(tag:, attrs: {}, pos: 0, source: "[#{tag}]")
  end

  describe "#initialize" do
    it "exposes AST::Align as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Align)
    end

    it "stores the explicit alignment so it overrides the tag name on later on_open calls" do
      handler = described_class.new("justify")

      handler.on_open(token: tag_start(tag: "center"), context:, registry:)

      expect(context.current.alignment).to eq("justify")
    end

    it "leaves alignment derivation to the tag name when none is given" do
      handler = described_class.new

      handler.on_open(token: tag_start(tag: "right"), context:, registry:)

      expect(context.current.alignment).to eq("right")
    end
  end

  describe "#on_open" do
    context "without an explicit alignment" do
      let(:handler) { described_class.new }

      it "uses the lowercased tag name as the alignment" do
        handler.on_open(token: tag_start(tag: "CENTER"), context:, registry:)

        expect(context.current).to be_a(Markbridge::AST::Align)
        expect(context.current.alignment).to eq("center")
      end

      it "preserves already-lowercase tag names" do
        handler.on_open(token: tag_start(tag: "right"), context:, registry:)

        expect(context.current.alignment).to eq("right")
      end
    end

    context "with an explicit alignment" do
      let(:handler) { described_class.new("justify") }

      it "uses the constructor alignment regardless of tag name" do
        handler.on_open(token: tag_start(tag: "center"), context:, registry:)

        expect(context.current.alignment).to eq("justify")
      end
    end

    it "forwards the token to context.push for graceful-degradation bookkeeping" do
      max = Markbridge::Parsers::BBCode::ParserState::MAX_DEPTH
      max.times { context.push(Markbridge::AST::Italic.new) }

      expect { described_class.new.on_open(token: tag_start, context:, registry:) }.to change(
        context,
        :depth_exceeded_count,
      ).by(1)
    end
  end
end
