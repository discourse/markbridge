# frozen_string_literal: true

RSpec.describe Markbridge::AST::Italic do
  it "is an Element" do
    element = described_class.new
    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "can have children" do
    element = described_class.new
    text = Markbridge::AST::Text.new("italic text")
    element << text

    expect(element.children).to eq([text])
  end
end
