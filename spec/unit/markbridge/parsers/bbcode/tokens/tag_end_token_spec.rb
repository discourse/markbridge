# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::TagEndToken do
  it "is a Token" do
    expect(described_class).to be < Markbridge::Parsers::BBCode::Token
  end

  describe "#initialize" do
    it "creates closing tag token with source" do
      token = described_class.new(tag: "b", pos: 10, source: "[/b]")

      expect(token.tag).to eq("b")
      expect(token.pos).to eq(10)
      expect(token.source).to eq("[/b]")
    end
  end

  describe "#inspect" do
    it "shows readable representation" do
      token = described_class.new(tag: "b", pos: 0, source: "[/b]")

      expect(token.inspect).to include("TagEndToken")
      expect(token.inspect).to include("[/b]")
    end
  end
end
