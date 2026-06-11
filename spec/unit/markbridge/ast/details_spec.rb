# frozen_string_literal: true

RSpec.describe Markbridge::AST::Details do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores the title" do
    element = described_class.new(title: "Show more")

    expect(element.title).to eq("Show more")
  end

  it "defaults to nil title" do
    element = described_class.new

    expect(element.title).to be_nil
  end

  it "can have children" do
    element = described_class.new(title: "Show")
    text = Markbridge::AST::Text.new("Body")
    element << text

    expect(element.children).to eq([text])
  end
end
