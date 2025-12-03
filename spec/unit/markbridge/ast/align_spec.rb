# frozen_string_literal: true

RSpec.describe Markbridge::AST::Align do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores the alignment value" do
    element = described_class.new(alignment: "center")

    expect(element.alignment).to eq("center")
  end

  it "defaults to nil alignment" do
    element = described_class.new

    expect(element.alignment).to be_nil
  end
end
