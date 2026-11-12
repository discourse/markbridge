# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::TableCellHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }
  let(:registry) do
    reg = Markbridge::Parsers::BBCode::HandlerRegistry.new
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry: reg)
    closing_strategy = Markbridge::Parsers::BBCode::ClosingStrategies::Reordering.new(reconciler)
    reg.instance_variable_set(:@closing_strategy, closing_strategy)
    reg.register(%w[td th], handler)
    reg
  end

  describe "#on_open" do
    before do
      table = Markbridge::AST::Table.new
      context.push(table)
      row = Markbridge::AST::TableRow.new
      context.push(row)
    end

    it "creates a non-header cell for td tag" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "td", attrs: {}, pos: 0, source: "[td]")

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::TableCell)
      expect(context.current.header?).to be false
    end

    it "reads colspan and rowspan from the attributes of the tag" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "td",
          attrs: {
            colspan: "2",
            rowspan: "3",
          },
          pos: 0,
          source: "[td colspan=2 rowspan=3]",
        )

      handler.on_open(token:, context:, registry:)

      expect(context.current.colspan).to eq(2)
      expect(context.current.rowspan).to eq(3)
    end

    it "creates a header cell for th tag" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "th", attrs: {}, pos: 0, source: "[th]")

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::TableCell)
      expect(context.current.header?).to be true
    end

    it "auto-closes previous TableCell" do
      token1 =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "td", attrs: {}, pos: 0, source: "[td]")
      token2 =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "td",
          attrs: {
          },
          pos: 10,
          source: "[td]",
        )

      handler.on_open(token: token1, context:, registry:)
      first_cell = context.current

      handler.on_open(token: token2, context:, registry:)
      second_cell = context.current

      expect(second_cell).to be_a(Markbridge::AST::TableCell)
      expect(second_cell).not_to eq(first_cell)
      # Both cells must be siblings, not nested (second_cell under
      # first_cell). Kills mutations that skip the `pop` guard.
      expect(first_cell.children).not_to include(second_cell)
    end

    it "does NOT pop when current is a TableRow (not a TableCell)" do
      # The `before` block leaves current as the TableRow. The first
      # cell opened must attach to that row as a sibling child, not
      # to the outer table.
      row_before = context.current
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "td", attrs: {}, pos: 0, source: "[td]")

      handler.on_open(token:, context:, registry:)

      expect(row_before).to be_a(Markbridge::AST::TableRow)
      expect(row_before.children.last).to eq(context.current)
    end

    def cell_token
      Markbridge::Parsers::BBCode::TagStartToken.new(tag: "td", attrs: {}, pos: 0, source: "[td]")
    end

    it "ends what is open in the cell before, and counts it" do
      row = context.current
      context.push(Markbridge::AST::TableCell.new)
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      handler.on_open(token: cell_token, context:, registry:)

      expect(row.children.size).to eq(2)
      expect(row.children.last).to eq(context.current)
      expect(context.auto_closed_count).to eq(2)
    end

    it "ends what is open directly in the row, and counts it" do
      row = context.current
      stray = Markbridge::AST::Bold.new
      context.push(stray)

      handler.on_open(token: cell_token, context:, registry:)

      expect(row.children).to eq([stray, context.current])
      expect(context.auto_closed_count).to eq(1)
    end

    it "opens what it has ended again in the new cell, with its values" do
      row = context.current
      context.push(Markbridge::AST::TableCell.new)
      context.push(Markbridge::AST::Color.new(color: "red"))
      context.push(Markbridge::AST::Bold.new)

      handler.on_open(
        token: cell_token,
        context:,
        registry: Markbridge::Parsers::BBCode::HandlerRegistry.default,
      )

      bold, color, cell = context.elements_from_current
      expect([bold.class, color.class]).to eq([Markbridge::AST::Bold, Markbridge::AST::Color])
      expect(color.color).to eq("red")
      expect(cell).to eq(row.children.last)
      expect(row.children.first.children.first).not_to equal(color)
    end

    it "opens nothing again that is open around the table" do
      state = Markbridge::Parsers::BBCode::ParserState.new(Markbridge::AST::Document.new)
      state.push(Markbridge::AST::Bold.new)
      state.push(Markbridge::AST::Table.new)
      state.push(Markbridge::AST::TableRow.new)
      state.push(Markbridge::AST::TableCell.new)
      state.push(Markbridge::AST::Italic.new)

      handler.on_open(
        token: cell_token,
        context: state,
        registry: Markbridge::Parsers::BBCode::HandlerRegistry.default,
      )

      expect(state.elements_from_current.first(2).map(&:class)).to eq(
        [Markbridge::AST::Italic, Markbridge::AST::TableCell],
      )
    end

    it "does not open an element again that does not end on its own" do
      row = context.current
      context.push(Markbridge::AST::TableCell.new)
      context.push(Markbridge::AST::Code.new)
      context.push(Markbridge::AST::Bold.new)

      handler.on_open(
        token: cell_token,
        context:,
        registry: Markbridge::Parsers::BBCode::HandlerRegistry.default,
      )

      bold, cell = context.elements_from_current
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(cell).to eq(row.children.last)
    end

    it "leaves the cell around a table in it open" do
      context.push(Markbridge::AST::TableCell.new)
      nested = Markbridge::AST::Table.new
      context.push(nested)

      handler.on_open(token: cell_token, context:, registry:)

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
        context.push(Markbridge::AST::TableCell.new)
        context.push(block)
        bold = Markbridge::AST::Bold.new
        context.push(bold)

        handler.on_open(token: cell_token, context:, registry:)

        expect(bold.children).to eq([context.current])
        expect(context.auto_closed_count).to eq(0)
      end
    end

    it "ends nothing without a table" do
      state = Markbridge::Parsers::BBCode::ParserState.new(Markbridge::AST::Document.new)
      bold = Markbridge::AST::Bold.new
      state.push(bold)

      handler.on_open(token: cell_token, context: state, registry:)

      expect(bold.children).to eq([state.current])
    end

    it "creates distinct cells for sequential `td`/`th` mix" do
      # Previous td → new th: both must still end up as siblings.
      td_token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "td", attrs: {}, pos: 0, source: "[td]")
      th_token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "th", attrs: {}, pos: 4, source: "[th]")

      handler.on_open(token: td_token, context:, registry:)
      td_cell = context.current

      handler.on_open(token: th_token, context:, registry:)
      th_cell = context.current

      expect(td_cell.header?).to be false
      expect(th_cell.header?).to be true
      expect(td_cell).not_to eq(th_cell)
    end
  end

  describe "#element_class" do
    it "returns AST::TableCell" do
      expect(handler.element_class).to eq(Markbridge::AST::TableCell)
    end
  end
end
