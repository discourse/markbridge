# frozen_string_literal: true

RSpec.describe Markbridge::AST::Element do
  # Use concrete subclass for testing base class functionality
  subject(:test_element_class) { Class.new(Markbridge::AST::Element) }

  describe "#initialize" do
    it "defaults to empty children" do
      element = test_element_class.new
      expect(element.children).to eq([])
    end
  end

  describe "#<<" do
    subject(:element) { test_element_class.new }

    it "adds child to children array" do
      child = Markbridge::AST::Text.new("hello")
      element << child
      expect(element.children).to include(child)
    end

    it "merges consecutive text children" do
      element << Markbridge::AST::Text.new("hello")
      element << Markbridge::AST::Text.new(" world")

      expect(element.children.size).to eq(1)
      expect(element.children.first.text).to eq("hello world")
    end

    it "does not merge non-consecutive text children" do
      element << child1 = Markbridge::AST::Text.new("hello")
      element << child2 = test_element_class.new
      element << child3 = Markbridge::AST::Text.new("world")

      expect(element.children.size).to eq(3)
      expect(element.children).to eq([child1, child2, child3])
    end

    it "returns self for chaining" do
      result = element << Markbridge::AST::Text.new("test")
      expect(result).to eq(element)
    end

    it "raises TypeError when given an Array" do
      children = [Markbridge::AST::Text.new("hello"), Markbridge::AST::Text.new(" world")]

      expect { element << children }.to raise_error(
        TypeError,
        "child must be a Markbridge::AST::Node (got Array)",
      )
    end

    it "raises TypeError for nil child" do
      expect { element << nil }.to raise_error(
        TypeError,
        "child must be a Markbridge::AST::Node (got nil)",
      )
    end
  end
end
