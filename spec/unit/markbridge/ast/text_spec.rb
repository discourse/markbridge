# frozen_string_literal: true

RSpec.describe Markbridge::AST::Text do
  describe "#initialize" do
    it "stores text content" do
      node = described_class.new("hello")
      expect(node.text).to eq("hello")
    end

    it "stores a mutable copy even when given a frozen string" do
      node = described_class.new("hello".freeze)

      expect(node.text).not_to be_frozen
    end
  end

  describe "#merge" do
    it "merges text from another text node" do
      node1 = described_class.new("hello")
      node2 = described_class.new(" world")

      result = node1.merge(node2)

      expect(node1.text).to eq("hello world")
      expect(result).to eq(node1)
    end

    it "handles empty text" do
      node1 = described_class.new("hello")
      node2 = described_class.new("")

      node1.merge(node2)
      expect(node1.text).to eq("hello")
    end
  end
end
