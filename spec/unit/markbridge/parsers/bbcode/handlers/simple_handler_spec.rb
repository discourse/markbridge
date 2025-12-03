# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::SimpleHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:element_class) { Markbridge::AST::Bold }
  let(:handler) { described_class.new(element_class) }

  describe "#initialize" do
    it "accepts an element class" do
      expect { described_class.new(Markbridge::AST::Bold) }.not_to raise_error
    end
  end

  describe "#on_open" do
    it "creates element and pushes to context" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "b", attrs: {}, pos: 0, source: "[b]")
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Bold)
    end

    it "creates the correct element class" do
      italic_handler = described_class.new(Markbridge::AST::Italic)
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "i", attrs: {}, pos: 0, source: "[i]")
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      italic_handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Italic)
    end
  end
end
