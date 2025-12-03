# frozen_string_literal: true

RSpec.describe Markbridge::AST::ListItem do
  it "is an Element" do
    element = described_class.new
    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "can have children" do
    element = described_class.new
    text = Markbridge::AST::Text.new("item text")
    element << text

    expect(element.children).to eq([text])
  end

  it "can contain complex content" do
    element = described_class.new
    element << Markbridge::AST::Text.new("text ")
    element << Markbridge::AST::Bold.new.tap { |b| b << Markbridge::AST::Text.new("bold") }

    expect(element.children.size).to eq(2)
    expect(element.children[0]).to be_a(Markbridge::AST::Text)
    expect(element.children[1]).to be_a(Markbridge::AST::Bold)
  end
end
