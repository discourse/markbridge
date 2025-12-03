# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Token do
  describe "#initialize" do
    it "accepts a position" do
      token = described_class.new(pos: 42)
      expect(token.pos).to eq(42)
    end

    it "accepts source text" do
      token = described_class.new(source: "[b]")
      expect(token.source).to eq("[b]")
    end

    it "defaults position to 0" do
      token = described_class.new
      expect(token.pos).to eq(0)
    end

    it "defaults source to nil" do
      token = described_class.new
      expect(token.source).to be_nil
    end
  end

  describe "#pos" do
    it "returns the position" do
      token = described_class.new(pos: 10)
      expect(token.pos).to eq(10)
    end
  end

  describe "#source" do
    it "returns the source text" do
      token = described_class.new(source: "[code]")
      expect(token.source).to eq("[code]")
    end
  end
end
