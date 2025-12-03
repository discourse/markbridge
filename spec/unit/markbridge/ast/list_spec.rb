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
end
