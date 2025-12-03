# frozen_string_literal: true

RSpec.describe Markbridge::AST::Email do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores the address" do
    element = described_class.new(address: "[email protected]")

    expect(element.address).to eq("[email protected]")
  end

  it "defaults to nil address" do
    element = described_class.new

    expect(element.address).to be_nil
  end
end
