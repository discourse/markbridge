# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::TableRowHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }
  let(:registry) do
    reg = Markbridge::Parsers::BBCode::HandlerRegistry.new
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry: reg)
    closing_strategy = Markbridge::Parsers::BBCode::ClosingStrategies::Reordering.new(reconciler)
    reg.instance_variable_set(:@closing_strategy, closing_strategy)
    reg.register("tr", handler)
    reg
  end
  let(:open_token) do
    Markbridge::Parsers::BBCode::TagStartToken.new(tag: "tr", attrs: {}, pos: 0, source: "[tr]")
  end

  describe "#on_open" do
    it "pushes a TableRow onto the context" do
      table = Markbridge::AST::Table.new
      context.push(table)

      handler.on_open(token: open_token, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::TableRow)
    end

    it "auto-closes previous TableRow" do
      table = Markbridge::AST::Table.new
      context.push(table)
      old_row = Markbridge::AST::TableRow.new
      context.push(old_row)

      handler.on_open(token: open_token, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::TableRow)
      expect(context.current).not_to eq(old_row)
    end

    it "auto-closes open TableCell before closing previous row" do
      table = Markbridge::AST::Table.new
      context.push(table)
      old_row = Markbridge::AST::TableRow.new
      context.push(old_row)
      cell = Markbridge::AST::TableCell.new
      context.push(cell)

      handler.on_open(token: open_token, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::TableRow)
      expect(context.current).not_to eq(old_row)
    end
  end

  describe "#on_close" do
    it "auto-closes open TableCell before closing row" do
      table = Markbridge::AST::Table.new
      context.push(table)
      row = Markbridge::AST::TableRow.new
      context.push(row)
      cell = Markbridge::AST::TableCell.new
      context.push(cell)

      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "tr", pos: 10, source: "[/tr]")

      handler.on_close(token: close_token, context:, registry:)

      expect(context.current).to eq(table)
    end
  end

  describe "#element_class" do
    it "returns AST::TableRow" do
      expect(handler.element_class).to eq(Markbridge::AST::TableRow)
    end
  end
end
