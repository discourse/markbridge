# frozen_string_literal: true

RSpec.describe Markbridge::AST::Size do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores the size" do
    element = described_class.new(size: "20")

    expect(element.size).to eq("20")
  end

  it "defaults to nil size" do
    element = described_class.new

    expect(element.size).to be_nil
  end

  it "can have children" do
    element = described_class.new
    text = Markbridge::AST::Text.new("Big text")
    element << text

    expect(element.children).to eq([text])
  end
end
