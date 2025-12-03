# frozen_string_literal: true

RSpec.describe Markbridge::AST::HorizontalRule do
  it "is a Node" do
    element = described_class.new
    expect(element).to be_a(Markbridge::AST::Node)
  end

  it "can be created without arguments" do
    element = described_class.new
    expect(element).to be_a(Markbridge::AST::HorizontalRule)
  end

  it "does not allow children" do
    element = described_class.new
    expect { element << Markbridge::AST::Text.new("nope") }.to raise_error(NoMethodError)
  end
end
