# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::TextToken do
  it "is a Token" do
    expect(described_class).to be < Markbridge::Parsers::BBCode::Token
  end

  it "creates text token" do
    token = described_class.new(text: "hello world", pos: 0)

    expect(token.text).to eq("hello world")
    expect(token.pos).to eq(0)
  end

  it "shows readable representation" do
    token = described_class.new(text: "test", pos: 0)
    expect(token.inspect).to include("TextToken")
    expect(token.inspect).to include('"test"')
  end
end
