# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::ListItemHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }
  let(:registry) do
    reg = Markbridge::Parsers::BBCode::HandlerRegistry.new
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry: reg)
    reg.closing_strategy =
      Markbridge::Parsers::BBCode::ClosingStrategies::Reordering.new(reconciler)
    reg.register("li", handler)
    reg
  end

  def tag_start(source: "[li]")
    Markbridge::Parsers::BBCode::TagStartToken.new(tag: "li", attrs: {}, pos: 0, source:)
  end

  describe "#initialize" do
    it "exposes AST::ListItem as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::ListItem)
    end
  end

  describe "#on_open" do
    it "pushes a ListItem as a child of the current element" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::ListItem)
      expect(document.children.first).to eq(context.current)
    end

    it "auto-closes a previous ListItem when opening a new one" do
      first = Markbridge::AST::ListItem.new
      context.push(first)

      handler.on_open(token: tag_start, context:, registry:)

      # The new ListItem is a sibling of the first, not a child
      expect(context.current).to be_a(Markbridge::AST::ListItem)
      expect(context.current).not_to eq(first)
      expect(first.children).not_to include(context.current)
    end

    it "nests inside a List when current is a List (does not pop the List)" do
      list = Markbridge::AST::List.new
      context.push(list)

      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::ListItem)
      # The list is the parent
      expect(list.children).to include(context.current)
    end

    it "nests directly under Document when current is Document (does not pop Document)" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(document.children).to include(context.current)
    end

    it "forwards the token to context.push for graceful-degradation bookkeeping" do
      max = Markbridge::Parsers::BBCode::ParserState::MAX_DEPTH
      max.times { context.push(Markbridge::AST::Italic.new) }

      expect { handler.on_open(token: tag_start, context:, registry:) }.to change(
        context,
        :depth_exceeded_count,
      ).by(1)
    end
  end

  describe "#on_close" do
    it "uses the default closing behavior (pops matching element)" do
      handler.on_open(token: tag_start, context:, registry:)
      list_item = context.current

      handler.on_close(
        token: Markbridge::Parsers::BBCode::TagEndToken.new(tag: "li", pos: 10, source: "[/li]"),
        context:,
        registry:,
      )

      expect(context.current).to eq(document)
      expect(document.children).to include(list_item)
    end
  end
end
