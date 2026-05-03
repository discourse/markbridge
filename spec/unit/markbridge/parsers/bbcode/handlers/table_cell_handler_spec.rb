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
