# frozen_string_literal: true

RSpec.describe Markbridge::AST::Code do
  it "is an Element" do
    element = described_class.new
    expect(element).to be_a(Markbridge::AST::Element)
  end

  describe "#language" do
    it "returns nil by default" do
      element = described_class.new
      expect(element.language).to be_nil
    end

    it "returns the language when set" do
      element = described_class.new(language: "ruby")
      expect(element.language).to eq("ruby")
    end
  end

  it "can have children" do
    element = described_class.new(language: "python")
    text = Markbridge::AST::Text.new("print('hello')")
    element << text

    expect(element.children).to eq([text])
  end
end
