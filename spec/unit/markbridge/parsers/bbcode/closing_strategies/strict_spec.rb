# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::ClosingStrategies::Strict do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:reconciler) { Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry:) }
  let(:root) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(root) }
  let(:strategy) { described_class.new(reconciler) }

  context "when current matches closing tag" do
    it "pops the element" do
      bold = Markbridge::AST::Bold.new
      context.push(bold)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      strategy.handle_close(token:, context:, registry:)

      expect(context.current).to eq(root)
    end
  end

  context "when current doesn't match but auto-close succeeds" do
    it "auto-closes to target" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      strategy.handle_close(token:, context:, registry:)

      expect(context.current).to eq(root)
      expect(context.auto_closed_count).to eq(2)
    end
  end

  context "when auto-close fails" do
    it "adds closing tag as text" do
      context.push(Markbridge::AST::Bold.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "i", pos: 0, source: "[/i]")

      strategy.handle_close(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Bold)
      expect(context.current.children.first.text).to eq("[/i]")
    end
  end

  context "when current is Document (which IS an Element)" do
    it "adds closing tag as text since Document has no handler" do
      # Document inherits from Element, so is_a?(Element) is true
      # But Document has no registered handler, so the closing tag becomes text
      expect(context.current).to eq(root)
      expect(root).to be_a(Markbridge::AST::Element)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      strategy.handle_close(token:, context:, registry:)

      expect(context.current).to eq(root)
      # Document IS an Element, so strategy doesn't return early
      # But there's no handler for Document, so [/b] becomes text
      expect(root.children.size).to eq(1)
      expect(root.children.first.text).to eq("[/b]")
    end
  end

  context "when called through actual parser flow" do
    it "orphaned closing tags become text" do
      # This is what actually happens in the parser
      parser = Markbridge::Parsers::BBCode::Parser.new
      result = parser.parse("[/b]")

      # The [/b] becomes text because there's no matching open
      expect(result.children.first.text).to eq("[/b]")
    end
  end
end
