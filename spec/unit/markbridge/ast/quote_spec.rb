# frozen_string_literal: true

RSpec.describe Markbridge::AST::Quote do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores author context attributes" do
    element = described_class.new(author: "Jane", post: "42", topic: "7", username: "jane_doe")

    expect(element.author).to eq("Jane")
    expect(element.post).to eq("42")
    expect(element.topic).to eq("7")
    expect(element.username).to eq("jane_doe")
  end

  it "defaults to nil attributes" do
    element = described_class.new

    expect(element.author).to be_nil
    expect(element.post).to be_nil
    expect(element.topic).to be_nil
    expect(element.username).to be_nil
  end
end
