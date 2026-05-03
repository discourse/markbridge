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

  # Kills the `super(pos:, source: text)` → `super(pos:, source: nil)`
  # mutation: source is forwarded from text so both accessors return
  # the same value.
  it "forwards text to source for the base-class accessor" do
    token = described_class.new(text: "hello", pos: 0)

    expect(token.source).to eq("hello")
  end

  it "freezes text so it can't be mutated in place" do
    token = described_class.new(text: +"hello", pos: 0)

    expect(token.text).to be_frozen
  end
end
