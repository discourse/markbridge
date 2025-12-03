# frozen_string_literal: true

RSpec.describe Markbridge::AST::Spoiler do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores the title" do
    element = described_class.new(title: "Click me")

    expect(element.title).to eq("Click me")
  end

  it "defaults to nil title" do
    element = described_class.new

    expect(element.title).to be_nil
  end

  it "can have children" do
    element = described_class.new(title: "Click to reveal")
    text = Markbridge::AST::Text.new("Hidden content")
    element << text

    expect(element.children).to eq([text])
  end
end
