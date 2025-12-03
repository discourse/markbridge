# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::RenderContext do
  describe "#initialize" do
    it "creates context with empty parents by default" do
      context = described_class.new
      expect(context.parents).to eq([])
    end

    it "creates context with given parents" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      context = described_class.new([bold, italic])

      expect(context.parents).to eq([bold, italic])
    end

    it "freezes the parents array" do
      context = described_class.new
      expect(context.parents).to be_frozen
    end
  end

  describe "#with_parent" do
    it "returns new context with element added" do
      context = described_class.new
      bold = Markbridge::AST::Bold.new

      new_context = context.with_parent(bold)

      expect(new_context).to be_a(described_class)
      expect(new_context.parents).to eq([bold])
    end

    it "does not modify original context" do
      bold = Markbridge::AST::Bold.new
      context = described_class.new([bold])

      italic = Markbridge::AST::Italic.new
      new_context = context.with_parent(italic)

      expect(context.parents).to eq([bold])
      expect(new_context.parents).to eq([bold, italic])
    end

    it "can be chained" do
      context = described_class.new
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new

      final_context = context.with_parent(bold).with_parent(italic)

      expect(final_context.parents).to eq([bold, italic])
    end
  end

  describe "#find_parent" do
    it "returns nil when no parents" do
      context = described_class.new
      expect(context.find_parent(Markbridge::AST::Bold)).to be_nil
    end

    it "returns nil when no matching parent" do
      italic = Markbridge::AST::Italic.new
      context = described_class.new([italic])

      expect(context.find_parent(Markbridge::AST::Bold)).to be_nil
    end

    it "finds matching parent" do
      bold = Markbridge::AST::Bold.new
      context = described_class.new([bold])

      expect(context.find_parent(Markbridge::AST::Bold)).to eq(bold)
    end

    it "finds closest matching parent when multiple exist" do
      list1 = Markbridge::AST::List.new(ordered: false)
      list2 = Markbridge::AST::List.new(ordered: true)
      context = described_class.new([list1, list2])

      result = context.find_parent(Markbridge::AST::List)
      expect(result).to eq(list2)
    end

    it "searches from most recent backwards" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      bold2 = Markbridge::AST::Bold.new
      context = described_class.new([bold, italic, bold2])

      result = context.find_parent(Markbridge::AST::Bold)
      expect(result).to eq(bold2)
    end
  end

  describe "#count_parents" do
    it "returns 0 when no parents" do
      context = described_class.new
      expect(context.count_parents(Markbridge::AST::Bold)).to eq(0)
    end

    it "returns 0 when no matching parents" do
      italic = Markbridge::AST::Italic.new
      context = described_class.new([italic])

      expect(context.count_parents(Markbridge::AST::Bold)).to eq(0)
    end

    it "counts matching parents" do
      list1 = Markbridge::AST::List.new(ordered: false)
      bold = Markbridge::AST::Bold.new
      list2 = Markbridge::AST::List.new(ordered: true)
      context = described_class.new([list1, bold, list2])

      expect(context.count_parents(Markbridge::AST::List)).to eq(2)
    end

    it "only counts exact type matches" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      context = described_class.new([bold, italic])

      expect(context.count_parents(Markbridge::AST::Bold)).to eq(1)
    end
  end

  describe "#has_parent?" do
    it "returns false when no parents" do
      context = described_class.new
      expect(context.has_parent?(Markbridge::AST::Bold)).to be false
    end

    it "returns false when no matching parent" do
      italic = Markbridge::AST::Italic.new
      context = described_class.new([italic])

      expect(context.has_parent?(Markbridge::AST::Bold)).to be false
    end

    it "returns true when matching parent exists" do
      bold = Markbridge::AST::Bold.new
      context = described_class.new([bold])

      expect(context.has_parent?(Markbridge::AST::Bold)).to be true
    end

    it "returns true when multiple matching parents exist" do
      list1 = Markbridge::AST::List.new(ordered: false)
      list2 = Markbridge::AST::List.new(ordered: true)
      context = described_class.new([list1, list2])

      expect(context.has_parent?(Markbridge::AST::List)).to be true
    end
  end

  describe "#root?" do
    it "returns true when no parents" do
      context = described_class.new
      expect(context.root?).to be true
    end

    it "returns false when parents exist" do
      bold = Markbridge::AST::Bold.new
      context = described_class.new([bold])

      expect(context.root?).to be false
    end
  end

  describe "#depth" do
    it "returns 0 for empty context" do
      context = described_class.new
      expect(context.depth).to eq(0)
    end

    it "returns parent count" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      context = described_class.new([bold, italic])

      expect(context.depth).to eq(2)
    end

    it "increases with each parent added" do
      context = described_class.new
      expect(context.depth).to eq(0)

      context1 = context.with_parent(Markbridge::AST::Bold.new)
      expect(context1.depth).to eq(1)

      context2 = context1.with_parent(Markbridge::AST::Italic.new)
      expect(context2.depth).to eq(2)
    end
  end

  describe "immutability" do
    it "prevents modifying parents array" do
      context = described_class.new

      expect { context.parents << Markbridge::AST::Bold.new }.to raise_error(FrozenError)
    end

    it "creates independent contexts" do
      context1 = described_class.new
      bold = Markbridge::AST::Bold.new
      context2 = context1.with_parent(bold)

      italic = Markbridge::AST::Italic.new
      context3 = context2.with_parent(italic)

      expect(context1.parents).to eq([])
      expect(context2.parents).to eq([bold])
      expect(context3.parents).to eq([bold, italic])
    end
  end
end
