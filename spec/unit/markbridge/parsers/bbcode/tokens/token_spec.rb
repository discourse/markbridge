# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Token do
  describe "#initialize" do
    it "stores position and source" do
      token = described_class.new(pos: 42, source: "[b]")
      expect(token.pos).to eq(42)
      expect(token.source).to eq("[b]")
    end
  end

  describe "#pos" do
    it "returns the position" do
      token = described_class.new(pos: 10, source: nil)
      expect(token.pos).to eq(10)
    end
  end

  describe "#source" do
    it "returns the source text" do
      token = described_class.new(pos: 0, source: "[code]")
      expect(token.source).to eq("[code]")
    end
  end
end
