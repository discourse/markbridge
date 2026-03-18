# frozen_string_literal: true

RSpec.describe Markbridge::AST::Heading do
  it "is an Element" do
    element = described_class.new(level: 1)
    expect(element).to be_a(Markbridge::AST::Element)
  end

  describe "#level" do
    it "returns the heading level" do
      element = described_class.new(level: 3)
      expect(element.level).to eq(3)
    end
  end

  it "can have children" do
    element = described_class.new(level: 2)
    text = Markbridge::AST::Text.new("Section Title")
    element << text

    expect(element.children).to eq([text])
  end
end
