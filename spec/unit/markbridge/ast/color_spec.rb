# frozen_string_literal: true

RSpec.describe Markbridge::AST::Color do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores the color value" do
    element = described_class.new(color: "red")

    expect(element.color).to eq("red")
  end

  it "defaults to nil color" do
    element = described_class.new

    expect(element.color).to be_nil
  end

  it "can have children" do
    element = described_class.new
    text = Markbridge::AST::Text.new("colored text")
    element << text

    expect(element.children).to eq([text])
  end
end
