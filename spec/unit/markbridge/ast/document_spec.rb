# frozen_string_literal: true

RSpec.describe Markbridge::AST::Document do
  describe "#initialize" do
    it "starts with empty children" do
      doc = described_class.new
      expect(doc.children).to eq([])
    end

    it "can be initialized with children" do
      child = Markbridge::AST::Text.new("test")
      doc = described_class.new([child])
      expect(doc.children).to eq([child])
    end
  end

  describe "#<<" do
    subject(:doc) { described_class.new }

    it "adds child to children array" do
      child = Markbridge::AST::Text.new("hello")
      doc << child
      expect(doc.children).to include(child)
    end

    it "merges consecutive text children" do
      doc << Markbridge::AST::Text.new("hello")
      doc << Markbridge::AST::Text.new(" world")

      expect(doc.children.size).to eq(1)
      expect(doc.children.first.text).to eq("hello world")
    end

    it "does not merge non-consecutive text children" do
      doc << child1 = Markbridge::AST::Text.new("hello")
      doc << child2 = Markbridge::AST::LineBreak.new
      doc << child3 = Markbridge::AST::Text.new("world")

      expect(doc.children.size).to eq(3)
      expect(doc.children).to eq([child1, child2, child3])
    end

    it "returns self for chaining" do
      result = doc << Markbridge::AST::Text.new("test")
      expect(result).to eq(doc)
    end

    it "raises TypeError when given an Array" do
      children = [Markbridge::AST::Text.new("hello"), Markbridge::AST::Text.new(" world")]
      expect { doc << children }.to raise_error(TypeError)
    end

    it "raises TypeError for nil child" do
      expect { doc << nil }.to raise_error(TypeError)
    end
  end
end
