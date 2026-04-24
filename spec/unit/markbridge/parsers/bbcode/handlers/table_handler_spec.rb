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

      # Pin the tree shape so the auto-close pops are observably
      # correct — cell stays inside row, row inside table, and the
      # outer table is closed so we're back at the document. Kills
      # mutations that skip either `if current.instance_of?(TableCell)`
      # or `if current.instance_of?(TableRow)` guards.
      expect(context.current).to eq(document)
      expect(row.children.last).to eq(cell)
      expect(table.children.last).to eq(row)
      expect(document.children.last).to eq(table)
    end

    it "does NOT pop anything extra when only the Table is on the stack" do
      # Kills `if context.current.instance_of?(AST::TableCell)` →
      # `if true` / `if context.current` / drop-if-keep-body. With
      # those mutations, `context.pop` fires unconditionally and
      # the Table itself gets popped off before `super` pops it
      # again, leaving the Document popped too — observable via
      # the document disappearing from the top of the stack.
      table = Markbridge::AST::Table.new
      context.push(table)

      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "table", pos: 10, source: "[/table]")

      handler.on_close(token: close_token, context:, registry:)

      # Expected: exactly ONE pop (from `super`), landing on document.
      expect(context.current).to eq(document)
      expect(document.children.last).to eq(table)
    end
  end

  describe "#element_class" do
    it "returns AST::Table" do
      expect(handler.element_class).to eq(Markbridge::AST::Table)
    end
  end
end
