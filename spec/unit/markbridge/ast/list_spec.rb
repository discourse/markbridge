# frozen_string_literal: true

RSpec.describe Markbridge::AST::List do
  it "is an Element" do
    element = described_class.new
    expect(element).to be_a(Markbridge::AST::Element)
  end

  describe "#ordered?" do
    it "returns false by default" do
      element = described_class.new
      expect(element.ordered?).to be false
    end

    it "returns true when created as ordered" do
      element = described_class.new(ordered: true)
      expect(element.ordered?).to be true
    end

    it "returns false when created as unordered" do
      element = described_class.new(ordered: false)
      expect(element.ordered?).to be false
    end
  end

  it "can have list item children" do
    element = described_class.new
    item = Markbridge::AST::ListItem.new
    element << item

    expect(element.children).to eq([item])
  end

  it "wraps non-list-item children in an implicit list item" do
    element = described_class.new
    element << Markbridge::AST::Text.new("wrapped")

    expect(element.children.size).to eq(1)
    expect(element.children.first).to be_a(Markbridge::AST::ListItem)
    expect(element.children.first.children.first.text).to eq("wrapped")
  end

  it "groups consecutive non-list-item children into the same implicit list item" do
    element = described_class.new
    element << Markbridge::AST::Text.new("first")
    element << Markbridge::AST::Bold.new

    expect(element.children.size).to eq(1)
    expect(element.children.first).to be_a(Markbridge::AST::ListItem)
    expect(element.children.first.children.size).to eq(2)
  end

  it "ignores whitespace-only text nodes" do
    element = described_class.new
    element << Markbridge::AST::Text.new("   \n\t ")

    expect(element.children).to be_empty
  end

  it "keeps text nodes that contain non-whitespace characters" do
    element = described_class.new
    element << Markbridge::AST::Text.new("  has content  ")

    expect(element.children.size).to eq(1)
    expect(element.children.first).to be_a(Markbridge::AST::ListItem)
  end

  it "returns self when ignoring whitespace-only text" do
    element = described_class.new
    result = element << Markbridge::AST::Text.new("   ")

    expect(result).to eq(element)
  end

  it "returns self when wrapping a non-list-item child" do
    element = described_class.new
    result = element << Markbridge::AST::Text.new("wrapped")

    expect(result).to eq(element)
  end

  it "returns self when adding a list item" do
    element = described_class.new
    result = element << Markbridge::AST::ListItem.new

    expect(result).to eq(element)
  end
end
