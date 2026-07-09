# frozen_string_literal: true

RSpec.describe Markbridge::AST::Quote do
  it "is an Element" do
    element = described_class.new

    expect(element).to be_a(Markbridge::AST::Element)
  end

  it "stores author context attributes" do
    element =
      described_class.new(
        author: "Jane",
        post_number: 42,
        post_id: 9001,
        topic_id: 7,
        username: "jane_doe",
        user_id: 12,
      )

    expect(element.author).to eq("Jane")
    expect(element.post_number).to eq(42)
    expect(element.post_id).to eq(9001)
    expect(element.topic_id).to eq(7)
    expect(element.username).to eq("jane_doe")
    expect(element.user_id).to eq(12)
  end

  it "defaults to nil attributes" do
    element = described_class.new

    expect(element.author).to be_nil
    expect(element.post_number).to be_nil
    expect(element.post_id).to be_nil
    expect(element.topic_id).to be_nil
    expect(element.username).to be_nil
    expect(element.user_id).to be_nil
  end

  it "can have children" do
    element = described_class.new
    text = Markbridge::AST::Text.new("quoted text")
    element << text

    expect(element.children).to eq([text])
  end
end
