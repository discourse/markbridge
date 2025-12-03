# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::ParserState do
  let(:root) { Markbridge::AST::Document.new }
  let(:context) { described_class.new(root) }

  describe "#initialize" do
    it "starts with root as current" do
      expect(context.current).to eq(root)
    end

    it "starts with depth 0" do
      expect(context.depth).to eq(0)
    end

    it "starts with auto_closed_count at 0" do
      expect(context.auto_closed_count).to eq(0)
    end
  end

  describe "#push" do
    it "adds element to current and makes it current" do
      element = Markbridge::AST::Bold.new
      context.push(element)

      expect(root.children).to include(element)
      expect(context.current).to eq(element)
      expect(context.depth).to eq(1)
    end

    it "auto-opens a list item when pushing into a List" do
      list = Markbridge::AST::List.new
      context.push(list)

      element = Markbridge::AST::Italic.new
      context.push(element)

      list_item = list.children.first
      expect(list_item).to be_a(Markbridge::AST::ListItem)
      expect(list_item.children).to include(element)
      expect(context.current).to eq(element)
    end

    it "raises when exceeding MAX_DEPTH and does not modify the tree" do
      described_class::MAX_DEPTH.times do
        element = Markbridge::AST::Bold.new
        context.push(element)
      end

      # Should stop at MAX_DEPTH
      expect(context.depth).to eq(described_class::MAX_DEPTH)

      rejected = Markbridge::AST::Italic.new
      expect { context.push(rejected) }.to raise_error(
        Markbridge::Parsers::BBCode::MaxDepthExceededError,
      )

      # Depth unchanged and rejected element not added
      expect(context.depth).to eq(described_class::MAX_DEPTH)
      expect(context.current.children).not_to include(rejected)
    end
  end

  describe "#pop" do
    it "returns to parent element" do
      element = Markbridge::AST::Bold.new
      context.push(element)
      context.pop

      expect(context.current).to eq(root)
      expect(context.depth).to eq(0)
    end

    it "doesn't pop beyond root" do
      context.pop
      expect(context.current).to eq(root)
      expect(context.depth).to eq(0)
    end

    it "handles multiple levels" do
      b = Markbridge::AST::Bold.new
      i = Markbridge::AST::Italic.new

      context.push(b)
      context.push(i)

      context.pop
      expect(context.current).to eq(b)

      context.pop
      expect(context.current).to eq(root)
    end

    it "does not increment auto_closed_count" do
      element = Markbridge::AST::Bold.new
      context.push(element)

      expect { context.pop }.not_to change(context, :auto_closed_count)
    end
  end

  describe "#add_child" do
    it "adds child to current without changing current" do
      text = Markbridge::AST::Text.new("hello")
      context.add_child(text)

      expect(root.children).to include(text)
      expect(context.current).to eq(root)
    end
  end

  describe "#auto_closed_count" do
    it "tracks manual auto-close increments" do
      expect { context.auto_close!(2) }.to change(context, :auto_closed_count).from(0).to(2)
    end
  end
end
