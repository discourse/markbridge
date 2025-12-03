# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::SelfClosingHandler do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:element_class) { Markbridge::AST::LineBreak }
  let(:handler) { described_class.new(element_class) }

  describe "#initialize" do
    it "accepts an element class" do
      expect do described_class.new(Markbridge::AST::LineBreak) end.not_to raise_error
    end
  end

  describe "#on_open" do
    it "creates element and adds to context" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "br", attrs: {}, pos: 0, source: "[br]")
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      handler.on_open(token:, context:, registry:)

      expect(document.children.last).to be_a(Markbridge::AST::LineBreak)
    end
  end

  describe "#on_close" do
    it "treats closing tag as text" do
      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "br", pos: 0, source: "[/br]")
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)

      handler.on_close(token:, context:, registry:)

      expect(document.children.last).to be_a(Markbridge::AST::Text)
      expect(document.children.last.text).to eq("[/br]")
    end
  end
end
