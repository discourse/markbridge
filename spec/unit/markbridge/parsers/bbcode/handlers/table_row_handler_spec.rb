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

    it "ends what is open in the cell of the row before, and counts it without the cell" do
      table = Markbridge::AST::Table.new
      context.push(table)
      context.push(Markbridge::AST::TableRow.new)
      context.push(Markbridge::AST::TableCell.new)
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      handler.on_open(token: open_token, context:, registry:)

      expect(table.children.last).to eq(context.current)
      expect(table.children.size).to eq(2)
      expect(context.auto_closed_count).to eq(2)
    end

    it "ends what is open directly in the table, and counts it" do
      table = Markbridge::AST::Table.new
      context.push(table)
      stray = Markbridge::AST::Bold.new
      context.push(stray)

      handler.on_open(token: open_token, context:, registry:)

      expect(table.children).to eq([stray, context.current])
      expect(context.auto_closed_count).to eq(1)
    end

    it "leaves the row around a table in a cell open" do
      context.push(Markbridge::AST::Table.new)
      context.push(Markbridge::AST::TableRow.new)
      context.push(Markbridge::AST::TableCell.new)
      nested = Markbridge::AST::Table.new
      context.push(nested)

      handler.on_open(token: open_token, context:, registry:)

      expect(nested.children).to eq([context.current])
    end

    [
      Markbridge::AST::Quote,
      Markbridge::AST::Spoiler,
      Markbridge::AST::Align,
      Markbridge::AST::List,
      Markbridge::AST::ListItem,
    ].each do |klass|
      it "ends nothing from inside a #{klass.name.split("::").last} in a cell" do
        block = klass == Markbridge::AST::Align ? klass.new(alignment: "center") : klass.new
        context.push(Markbridge::AST::Table.new)
        context.push(Markbridge::AST::TableRow.new)
        context.push(Markbridge::AST::TableCell.new)
        context.push(block)
        bold = Markbridge::AST::Bold.new
        context.push(bold)

        handler.on_open(token: open_token, context:, registry:)

        expect(bold.children).to eq([context.current])
        expect(context.auto_closed_count).to eq(0)
      end
    end

    it "ends nothing without a table" do
      bold = Markbridge::AST::Bold.new
      context.push(bold)

      handler.on_open(token: open_token, context:, registry:)

      expect(bold.children).to eq([context.current])
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
