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

    it "exposes depth equal to parents.size" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new

      expect(described_class.new.depth).to eq(0)
      expect(described_class.new([bold, italic]).depth).to eq(2)
    end

    it "exposes the parents array to query methods" do
      bold = Markbridge::AST::Bold.new
      context = described_class.new([bold])

      expect(context.find_parent(Markbridge::AST::Bold)).to eq(bold)
    end

    it "defaults html_mode to false" do
      expect(described_class.new.html_mode?).to be false
    end

    it "stores the html_mode kwarg as-is" do
      expect(described_class.new([], html_mode: true).html_mode?).to be true
    end

    it "exposes the nearest parent element (nil at root)" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      context = described_class.new

      expect(context.element).to be_nil
      expect(context.with_parent(bold).element).to be(bold)
      expect(described_class.new([bold, italic]).element).to be(italic)
    end

    it "links each context created by with_parent back to its origin" do
      context = described_class.new
      new_context = context.with_parent(Markbridge::AST::Bold.new)

      expect(new_context.parent_context).to be(context)
    end

    it "increments depth once per chained parent" do
      context = described_class.new
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new

      expect(context.with_parent(bold).depth).to eq(1)
      expect(context.with_parent(bold).with_parent(italic).depth).to eq(2)
    end

    it "supports the chain form without an enclosing context" do
      bold = Markbridge::AST::Bold.new
      context = described_class.new(element: bold)

      expect(context.depth).to eq(1)
      expect(context.parents).to eq([bold])
      expect(context.find_parent(Markbridge::AST::Italic)).to be_nil
    end

    it "ignores the parents array when an element is given" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      context = described_class.new([italic], element: bold)

      expect(context.parents).to eq([bold])
    end

    it "propagates html_mode into the contexts built from a parents array" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      context = described_class.new([bold, italic], html_mode: true)

      expect(context.parent_context.html_mode?).to be true
    end

    it "keeps depth in sync when toggling html_mode mid-chain" do
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      context = described_class.new([bold, italic]).with_html_mode(true)

      expect(context.depth).to eq(2)
      expect(context.element).to be(italic)
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

    it "exposes the added parent via find_parent" do
      bold = Markbridge::AST::Bold.new
      new_context = described_class.new.with_parent(bold)

      expect(new_context.find_parent(Markbridge::AST::Bold)).to eq(bold)
    end

    it "tracks repeated additions of the same class" do
      bold1 = Markbridge::AST::Bold.new
      bold2 = Markbridge::AST::Bold.new
      ctx = described_class.new.with_parent(bold1).with_parent(bold2)

      expect(ctx.count_parents(Markbridge::AST::Bold)).to eq(2)
      expect(ctx.find_parent(Markbridge::AST::Bold)).to eq(bold2)
    end

    it "increments depth by one on each call" do
      ctx = described_class.new
      expect(ctx.with_parent(Markbridge::AST::Bold.new).depth).to eq(1)
      expect(
        ctx.with_parent(Markbridge::AST::Bold.new).with_parent(Markbridge::AST::Italic.new).depth,
      ).to eq(2)
    end

    it "does not mutate the original context (functional, not in-place update)" do
      bold = Markbridge::AST::Bold.new
      original = described_class.new
      original.with_parent(bold)

      expect(original.find_parent(Markbridge::AST::Bold)).to be_nil
      expect(original.count_parents(Markbridge::AST::Bold)).to eq(0)
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

    it "returns a subclass instance when queried by the base class" do
      custom_url_class = Class.new(Markbridge::AST::Url)
      instance = custom_url_class.new
      context = described_class.new([instance])

      expect(context.find_parent(Markbridge::AST::Url)).to equal(instance)
    end

    it "returns the closest subclass when mixed with exact-class instances" do
      base = Markbridge::AST::Url.new
      sub = Class.new(Markbridge::AST::Url).new
      context = described_class.new([base, sub])

      expect(context.find_parent(Markbridge::AST::Url)).to equal(sub)
    end

    it "finds a match beyond the nearest parent (the walk must advance)" do
      # Three levels deep so a walk that fails to advance past the second
      # node (e.g. re-reading the start context's parent) can't fake it.
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      underline = Markbridge::AST::Underline.new
      context = described_class.new([bold, italic, underline])

      expect(context.find_parent(Markbridge::AST::Bold)).to be(bold)
    end

    it "walks a chain that has no enclosing root context" do
      context = described_class.new(element: Markbridge::AST::Bold.new)

      expect(context.find_parent(Markbridge::AST::Italic)).to be_nil
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

    it "counts parents on a chain that has no enclosing root context" do
      context = described_class.new(element: Markbridge::AST::Bold.new)

      expect(context.count_parents(Markbridge::AST::Bold)).to eq(1)
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

    it "counts subclass instances when queried by base class" do
      custom_url_class = Class.new(Markbridge::AST::Url)
      context = described_class.new([custom_url_class.new, custom_url_class.new])

      expect(context.count_parents(Markbridge::AST::Url)).to eq(2)
    end

    it "sums exact-class and subclass instances when queried by base class" do
      sub = Class.new(Markbridge::AST::Url)
      context = described_class.new([Markbridge::AST::Url.new, sub.new, Markbridge::AST::Url.new])

      expect(context.count_parents(Markbridge::AST::Url)).to eq(3)
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

    it "returns true when a subclass of the queried class is in the chain" do
      custom_url_class = Class.new(Markbridge::AST::Url)
      context = described_class.new([custom_url_class.new])

      expect(context.has_parent?(Markbridge::AST::Url)).to be true
    end

    it "sees a match beyond the nearest parent (the walk must advance)" do
      # Three levels deep so a walk that fails to advance past the second
      # node (e.g. re-reading the start context's parent) can't fake it.
      bold = Markbridge::AST::Bold.new
      italic = Markbridge::AST::Italic.new
      underline = Markbridge::AST::Underline.new
      context = described_class.new([bold, italic, underline])

      expect(context.has_parent?(Markbridge::AST::Bold)).to be true
    end

    it "walks a chain that has no enclosing root context" do
      context = described_class.new(element: Markbridge::AST::Bold.new)

      expect(context.has_parent?(Markbridge::AST::Italic)).to be false
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

  describe "#html_mode?" do
    it "defaults to false" do
      context = described_class.new
      expect(context.html_mode?).to be false
    end

    it "is true when constructed with html_mode: true" do
      context = described_class.new([], html_mode: true)
      expect(context.html_mode?).to be true
    end
  end

  describe "#with_html_mode" do
    it "returns a new context with html_mode set" do
      context = described_class.new
      new_context = context.with_html_mode(true)

      expect(new_context.html_mode?).to be true
      expect(context.html_mode?).to be false
    end

    it "preserves parents" do
      bold = Markbridge::AST::Bold.new
      context = described_class.new([bold])

      new_context = context.with_html_mode(true)

      expect(new_context.parents).to eq([bold])
      expect(new_context.find_parent(Markbridge::AST::Bold)).to eq(bold)
    end

    it "can be turned off again" do
      context = described_class.new([], html_mode: true)
      new_context = context.with_html_mode(false)

      expect(new_context.html_mode?).to be false
    end
  end

  describe "html_mode propagation through with_parent" do
    it "carries html_mode forward when descending" do
      context = described_class.new([], html_mode: true)
      bold = Markbridge::AST::Bold.new

      new_context = context.with_parent(bold)

      expect(new_context.html_mode?).to be true
    end

    it "stays false when starting from default context" do
      context = described_class.new
      bold = Markbridge::AST::Bold.new

      new_context = context.with_parent(bold)

      expect(new_context.html_mode?).to be false
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
