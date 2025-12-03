# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::ListItemHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }
  let(:registry) do
    reg = Markbridge::Parsers::BBCode::HandlerRegistry.new
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry: reg)
    closing_strategy = Markbridge::Parsers::BBCode::ClosingStrategies::Reordering.new(reconciler)
    reg.instance_variable_set(:@closing_strategy, closing_strategy)
    reg
  end

  describe "#on_open" do
    it "creates a list item and pushes to context" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "li", attrs: {}, pos: 0, source: "[li]")

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::ListItem)
    end

    it "pushes list item onto context stack" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "li", attrs: {}, pos: 0, source: "[li]")

      expect { handler.on_open(token:, context:, registry:) }.to(
        change { context.current.class }.from(Markbridge::AST::Document).to(
          Markbridge::AST::ListItem,
        ),
      )
    end
  end

  describe "#on_close" do
    it "uses default closing behavior from BaseHandler" do
      open_token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "li", attrs: {}, pos: 0, source: "[li]")
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "li", pos: 10, source: "[/li]")

      # Register handler so the element can be closed properly
      registry.register("li", handler)

      handler.on_open(token: open_token, context:, registry:)
      list_item = context.current
      expect(list_item).to be_a(Markbridge::AST::ListItem)

      handler.on_close(token: close_token, context:, registry:)
      expect(context.current).to eq(document)
      expect(document.children).to include(list_item)
    end
  end
end
