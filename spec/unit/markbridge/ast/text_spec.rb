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

    it "does not share its buffer with the caller's string" do
      original = +"hello"
      node = described_class.new(original)

      expect(node.text).not_to be(original)
    end
  end

  describe "buffer isolation" do
    # Regression: Text used to be initialized with `+text`, which is a no-op
    # on already-mutable strings. A later #merge would then `<<` into the
    # caller's original buffer, surprising any code still holding the source
    # reference.
    it "does not mutate the caller's string when merge is called later" do
      original = +"hello"
      node1 = described_class.new(original)
      node2 = described_class.new(" world")

      node1.merge(node2)

      expect(original).to eq("hello")
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
