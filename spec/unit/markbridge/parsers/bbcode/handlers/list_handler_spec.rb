# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::ListHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }
  let(:registry) do
    reg = Markbridge::Parsers::BBCode::HandlerRegistry.new
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry: reg)
    reg.closing_strategy =
      Markbridge::Parsers::BBCode::ClosingStrategies::Reordering.new(reconciler)
    reg.register("list", handler)
    reg
  end

  def tag_start(tag: "list", attrs: {})
    Markbridge::Parsers::BBCode::TagStartToken.new(tag:, attrs:, pos: 0, source: "[#{tag}]")
  end

  def tag_end(tag: "list")
    Markbridge::Parsers::BBCode::TagEndToken.new(tag:, pos: 10, source: "[/#{tag}]")
  end

  describe "#initialize" do
    it "exposes AST::List as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::List)
    end
  end

  describe "#on_open" do
    it "creates an unordered list by default" do
      handler.on_open(token: tag_start, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::List)
      expect(context.current.ordered?).to be false
    end

    it "creates an ordered list for the 'ol' tag" do
      handler.on_open(token: tag_start(tag: "ol"), context:, registry:)

      expect(context.current.ordered?).to be true
    end

    it "creates an ordered list for the 'olist' tag" do
      handler.on_open(token: tag_start(tag: "olist"), context:, registry:)

      expect(context.current.ordered?).to be true
    end

    it "creates an ordered list when attrs[:type] == '1'" do
      handler.on_open(token: tag_start(attrs: { type: "1" }), context:, registry:)

      expect(context.current.ordered?).to be true
    end

    it "does not treat type values other than '1' as ordered" do
      handler.on_open(token: tag_start(attrs: { type: "A" }), context:, registry:)

      expect(context.current.ordered?).to be false
    end

    it "creates an ordered list when attrs[:option] == '1'" do
      handler.on_open(token: tag_start(attrs: { option: "1" }), context:, registry:)

      expect(context.current.ordered?).to be true
    end

    it "does not treat option values other than '1' as ordered" do
      handler.on_open(token: tag_start(attrs: { option: "A" }), context:, registry:)

      expect(context.current.ordered?).to be false
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
    it "pops the list when it is the current element" do
      list = Markbridge::AST::List.new
      context.push(list)

      handler.on_close(token: tag_end, context:, registry:)

      expect(context.current).to eq(document)
      expect(document.children).to include(list)
    end

    it "auto-closes an open ListItem before closing the list" do
      list = Markbridge::AST::List.new
      context.push(list)
      item = Markbridge::AST::ListItem.new
      context.push(item)

      handler.on_close(token: tag_end, context:, registry:)

      # Both the item and the list are popped
      expect(context.current).to eq(document)
      expect(list.children).to include(item)
    end

    it "does not pop non-ListItem current elements" do
      list = Markbridge::AST::List.new
      context.push(list)
      bold = Markbridge::AST::Bold.new
      context.push(bold)

      handler.on_close(token: tag_end, context:, registry:)

      # Bold stays current; close_element couldn't match list since Bold
      # blocks; the [/list] becomes text inside Bold.
      expect(context.current).to eq(bold)
    end
  end
end
