# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::ListHandler do
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
    it "creates unordered list by default" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "list",
          attrs: {
          },
          pos: 0,
          source: "[list]",
        )

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::List)
      expect(context.current.ordered?).to be false
    end

    it "creates ordered list for 'ol' tag" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag: "ol", attrs: {}, pos: 0, source: "[ol]")

      handler.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::List)
      expect(context.current.ordered?).to be true
    end

    it "creates ordered list for 'olist' tag" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "olist",
          attrs: {
          },
          pos: 0,
          source: "[olist]",
        )

      handler.on_open(token:, context:, registry:)

      expect(context.current.ordered?).to be true
    end

    it "creates ordered list when type=1" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "list",
          attrs: {
            type: "1",
          },
          pos: 0,
          source: "[list=1]",
        )

      handler.on_open(token:, context:, registry:)

      expect(context.current.ordered?).to be true
    end

    it "creates ordered list when option=1" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "list",
          attrs: {
            option: "1",
          },
          pos: 0,
          source: "[list=1]",
        )

      handler.on_open(token:, context:, registry:)

      expect(context.current.ordered?).to be true
    end

    it "pushes list onto context stack" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "list",
          attrs: {
          },
          pos: 0,
          source: "[list]",
        )

      expect { handler.on_open(token:, context:, registry:) }.to(
        change { context.current.class }.from(Markbridge::AST::Document).to(Markbridge::AST::List),
      )
    end
  end

  describe "#on_close" do
    it "pops list from context when no list items are open" do
      # Setup: open a list
      list = Markbridge::AST::List.new(ordered: false)
      context.push(list)

      # Register handler so closing works
      registry.register("list", handler)

      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "list", pos: 10, source: "[/list]")

      handler.on_close(token: close_token, context:, registry:)

      expect(context.current).to eq(document)
      expect(document.children).to include(list)
    end
  end
end
