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
      # The new row must be a direct child of the table, not nested
      # under the old row or cell — kills mutations that skip the
      # pop-cell / pop-row steps.
      new_row = context.current
      expect(table.children.last).to eq(new_row)
      expect(old_row.children.last).to eq(cell)
    end

    it "does NOT pop when current is a non-table-container element" do
      # A stray non-table element (e.g. Paragraph) must not be popped
      # by [tr]; the new row is inserted as its child instead. Kills
      # `if true` / `if context.is_a?(...)` mutations that would pop
      # the wrong thing.
      table = Markbridge::AST::Table.new
      context.push(table)
      stray = Markbridge::AST::Paragraph.new
      context.push(stray)

      handler.on_open(token: open_token, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::TableRow)
      expect(stray.children.last).to eq(context.current)
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

    it "does NOT pop an extra level when no TableCell is open" do
      # Kills `if context.current.instance_of?(AST::TableCell)` →
      # `if true` / `if context.current` / `if AST::TableCell` /
      # drop-if-keep-body. With those, `context.pop` would fire on
      # the TableRow itself before `super` pops it, leaving us on
      # the document instead of the intended "back to table" state.
      table = Markbridge::AST::Table.new
      context.push(table)
      row = Markbridge::AST::TableRow.new
      context.push(row)

      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "tr", pos: 10, source: "[/tr]")

      handler.on_close(token: close_token, context:, registry:)

      # Only one pop (from super). Context should be on the table.
      expect(context.current).to eq(table)
    end
  end

  describe "#element_class" do
    it "returns AST::TableRow" do
      expect(handler.element_class).to eq(Markbridge::AST::TableRow)
    end
  end
end
