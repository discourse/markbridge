# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::TableHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }
  let(:registry) do
    reg = Markbridge::Parsers::BBCode::HandlerRegistry.new
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry: reg)
    closing_strategy = Markbridge::Parsers::BBCode::ClosingStrategies::Reordering.new(reconciler)
    reg.instance_variable_set(:@closing_strategy, closing_strategy)
    reg.register("table", handler)
    reg
  end

  describe "#on_open" do
    it "pushes a Table onto the context" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "table",
          attrs: {
          },
          pos: 0,
          source: "[table]",
        )

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Table)
    end
  end

  describe "#on_close" do
    it "pops the table from context" do
      table = Markbridge::AST::Table.new
      context.push(table)

      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "table", pos: 10, source: "[/table]")

      handler.on_close(token: close_token, context:, registry:)

      expect(context.current).to eq(document)
    end

    it "auto-closes open TableRow before closing table" do
      table = Markbridge::AST::Table.new
      context.push(table)
      row = Markbridge::AST::TableRow.new
      context.push(row)

      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "table", pos: 10, source: "[/table]")

      handler.on_close(token: close_token, context:, registry:)

      expect(context.current).to eq(document)
    end

    it "auto-closes open TableCell and TableRow before closing table" do
      table = Markbridge::AST::Table.new
      context.push(table)
      row = Markbridge::AST::TableRow.new
      context.push(row)
      cell = Markbridge::AST::TableCell.new
      context.push(cell)

      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "table", pos: 10, source: "[/table]")

      handler.on_close(token: close_token, context:, registry:)

      expect(context.current).to eq(document)
    end
  end

  describe "#element_class" do
    it "returns AST::Table" do
      expect(handler.element_class).to eq(Markbridge::AST::Table)
    end
  end
end
