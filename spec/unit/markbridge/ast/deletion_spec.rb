# frozen_string_literal: true

RSpec.describe Markbridge::AST::Deletion do
  it "is an Element" do
    expect(described_class.new).to be_a(Markbridge::AST::Element)
  end

  it "can have children" do
    element = described_class.new
    text = Markbridge::AST::Text.new("x")
    element << text

    expect(element.children).to eq([text])
  end
end
