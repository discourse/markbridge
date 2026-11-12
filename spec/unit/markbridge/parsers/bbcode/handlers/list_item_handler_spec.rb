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

    it "closes what is still open in the item in front, and counts it" do
      list = Markbridge::AST::List.new
      context.push(list)
      first = Markbridge::AST::ListItem.new
      context.push(first)
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      handler.on_open(token: tag_start, context:, registry:)

      expect(list.children).to eq([first, context.current])
      expect(context.auto_closed_count).to eq(2)
    end

    it "counts nothing as auto-closed for an item that follows an item" do
      context.push(Markbridge::AST::List.new)
      context.push(Markbridge::AST::ListItem.new)

      handler.on_open(token: tag_start, context:, registry:)

      expect(context.auto_closed_count).to eq(0)
    end

    it "closes what is open directly in the list, and counts it" do
      list = Markbridge::AST::List.new
      bold = Markbridge::AST::Bold.new
      context.push(list)
      context.push(bold)
      context.push(Markbridge::AST::Italic.new)

      handler.on_open(token: tag_start, context:, registry:)

      # The list puts what is no item into an item of its own.
      expect(list.children.map(&:class)).to eq([Markbridge::AST::ListItem] * 2)
      expect(list.children.first.children).to eq([bold])
      expect(list.children.last).to eq(context.current)
      expect(context.auto_closed_count).to eq(2)
    end

    it "opens what it has ended again in the new item, with its values" do
      list = Markbridge::AST::List.new
      context.push(list)
      context.push(Markbridge::AST::ListItem.new)
      context.push(Markbridge::AST::Color.new(color: "red"))
      context.push(Markbridge::AST::Bold.new)

      handler.on_open(
        token: tag_start,
        context:,
        registry: Markbridge::Parsers::BBCode::HandlerRegistry.default,
      )

      bold, color, item = context.elements_from_current
      expect([bold.class, color.class]).to eq([Markbridge::AST::Bold, Markbridge::AST::Color])
      expect(color.color).to eq("red")
      expect(item).to eq(list.children.last)
      expect(list.children.first.children.first).not_to equal(color)
    end

    it "opens what was open directly in the list again in the item" do
      list = Markbridge::AST::List.new
      context.push(list)
      context.push(Markbridge::AST::Bold.new)

      handler.on_open(
        token: tag_start,
        context:,
        registry: Markbridge::Parsers::BBCode::HandlerRegistry.default,
      )

      expect(context.current).to be_a(Markbridge::AST::Bold)
      expect(list.children.last.children).to eq([context.current])
    end

    it "does not open an element again that does not end on its own" do
      list = Markbridge::AST::List.new
      context.push(list)
      context.push(Markbridge::AST::ListItem.new)
      context.push(Markbridge::AST::Table.new)
      context.push(Markbridge::AST::Bold.new)

      handler.on_open(
        token: tag_start,
        context:,
        registry: Markbridge::Parsers::BBCode::HandlerRegistry.default,
      )

      bold, item = context.elements_from_current
      expect(bold).to be_a(Markbridge::AST::Bold)
      expect(item).to eq(list.children.last)
    end

    it "opens nothing again for a [*] that ends nothing" do
      quote = Markbridge::AST::Quote.new
      context.push(quote)
      context.push(Markbridge::AST::Bold.new)

      handler.on_open(
        token: tag_start,
        context:,
        registry: Markbridge::Parsers::BBCode::HandlerRegistry.default,
      )

      expect(context.current).to be_a(Markbridge::AST::ListItem)
      expect(context.current.children).to eq([])
    end

    it "leaves the item around a nested list open" do
      context.push(Markbridge::AST::List.new)
      outer_item = Markbridge::AST::ListItem.new
      context.push(outer_item)
      nested = Markbridge::AST::List.new
      context.push(nested)

      handler.on_open(token: tag_start, context:, registry:)

      expect(nested.children).to eq([context.current])
      expect(outer_item.children).to eq([nested])
    end

    it "stays inside an element that is open outside of any item" do
      bold = Markbridge::AST::Bold.new
      context.push(bold)

      handler.on_open(token: tag_start, context:, registry:)

      expect(bold.children).to eq([context.current])
      expect(context.auto_closed_count).to eq(0)
    end

    [
      Markbridge::AST::Quote,
      Markbridge::AST::Spoiler,
      Markbridge::AST::Align,
      Markbridge::AST::TableCell,
    ].each do |klass|
      it "is text in a #{klass.name.split("::").last} that is open inside an item" do
        item = Markbridge::AST::ListItem.new
        block = klass == Markbridge::AST::Align ? klass.new(alignment: "center") : klass.new
        context.push(Markbridge::AST::List.new)
        context.push(item)
        context.push(block)
        context.push(Markbridge::AST::Bold.new)

        handler.on_open(token: tag_start(source: "[*]"), context:, registry:)

        expect(context.current).to be_a(Markbridge::AST::Bold)
        expect(context.current.children.map(&:text)).to eq(["[*]"])
        expect(context.auto_closed_count).to eq(0)
      end
    end

    it "starts an item in a quote that has no list around it" do
      quote = Markbridge::AST::Quote.new
      context.push(quote)

      handler.on_open(token: tag_start, context:, registry:)

      expect(quote.children).to eq([context.current])
      expect(context.current).to be_a(Markbridge::AST::ListItem)
    end

    it "starts an item in a list that is inside a quote" do
      list = Markbridge::AST::List.new
      context.push(Markbridge::AST::List.new)
      context.push(Markbridge::AST::ListItem.new)
      context.push(Markbridge::AST::Quote.new)
      context.push(list)

      handler.on_open(token: tag_start, context:, registry:)

      expect(list.children).to eq([context.current])
    end

    it "closes an item whose list is inside a quote" do
      list = Markbridge::AST::List.new
      first = Markbridge::AST::ListItem.new
      context.push(Markbridge::AST::Quote.new)
      context.push(list)
      context.push(first)

      handler.on_open(token: tag_start, context:, registry:)

      expect(list.children).to eq([first, context.current])
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
