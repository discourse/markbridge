# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::TagStartToken do
  it "is a Token" do
    expect(described_class).to be < Markbridge::Parsers::BBCode::Token
  end

  describe "#initialize" do
    it "creates opening tag token with attributes and source" do
      token =
        described_class.new(
          tag: "url",
          attrs: {
            href: "https://example.com",
          },
          pos: 10,
          source: "[url href=\"https://example.com\"]",
        )

      expect(token.tag).to eq("url")
      expect(token.attrs).to eq({ href: "https://example.com" })
      expect(token.pos).to eq(10)
      expect(token.source).to eq("[url href=\"https://example.com\"]")
    end

    it "defaults to empty attributes" do
      token = described_class.new(tag: "b", pos: 0, source: "[b]")
      expect(token.attrs).to eq({})
    end

    it "defaults source to nil" do
      token = described_class.new(tag: "b", pos: 0)
      expect(token.source).to be_nil
    end
  end

  describe "#inspect" do
    it "shows readable representation" do
      token =
        described_class.new(
          tag: "url",
          attrs: {
            href: "test",
          },
          pos: 0,
          source: "[url href=\"test\"]",
        )
      expect(token.inspect).to include("TagStartToken")
      expect(token.inspect).to include("[url]")
      expect(token.inspect).to include("href")
      expect(token.inspect).to include("test")
    end
  end
end
