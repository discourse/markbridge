# frozen_string_literal: true

RSpec.describe Markbridge::AST::MarkdownText do
  describe "#initialize" do
    it "creates a markdown text node with content" do
      text = described_class.new("**bold** text")
      expect(text.text).to eq("**bold** text")
    end

    it "creates a mutable copy of the string" do
      original = "text"
      text = described_class.new(original)
      text.instance_variable_get(:@text) << " more"

      expect(text.text).to eq("text more")
      expect(original).to eq("text")
    end
  end

  describe "#merge" do
    it "merges another markdown text node's content" do
      text1 = described_class.new("**bold**")
      text2 = described_class.new(" and *italic*")

      text1.merge(text2)
      expect(text1.text).to eq("**bold** and *italic*")
    end

    it "returns self for method chaining" do
      text1 = described_class.new("first")
      text2 = described_class.new("second")

      result = text1.merge(text2)
      expect(result).to be(text1)
    end
  end
end
