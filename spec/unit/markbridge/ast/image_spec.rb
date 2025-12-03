# frozen_string_literal: true

RSpec.describe Markbridge::AST::Image do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores the source and dimensions" do
    element = described_class.new(src: "https://example.com/img.png", width: 100, height: 200)

    expect(element.src).to eq("https://example.com/img.png")
    expect(element.width).to eq(100)
    expect(element.height).to eq(200)
  end

  it "defaults to nil values" do
    element = described_class.new

    expect(element.src).to be_nil
    expect(element.width).to be_nil
    expect(element.height).to be_nil
  end
end
