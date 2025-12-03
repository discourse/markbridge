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
end
