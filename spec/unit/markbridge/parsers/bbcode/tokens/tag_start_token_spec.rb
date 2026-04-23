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

    # Kills the `.freeze` drop on `@tag` and `@attrs`. Pass deliberately-
    # mutable inputs (the `+""` form is guaranteed unfrozen); without
    # `.freeze`, the stored ivars would stay mutable and the frozen?
    # assertions would fail.
    it "freezes tag and attrs so they can't be mutated in place" do
      token = described_class.new(tag: +"b", attrs: { cls: +"foo" }, pos: 0, source: "[b]")

      expect(token.tag).to be_frozen
      expect(token.attrs).to be_frozen
    end
  end

  describe "#inspect" do
    it "shows readable representation with attrs" do
      token =
        described_class.new(
          tag: "url",
          attrs: {
            href: "test",
          },
          pos: 0,
          source: "[url href=\"test\"]",
        )

      expect(token.inspect).to eq('#<TagStartToken [url] {href: "test"}>')
    end

    # Kills `attrs.empty? ? "" : " #{attrs.inspect}"` ternary branch
    # mutations (branch collapse, `nil` → empty, `if false`).
    it "omits the attrs section when attrs is empty" do
      token = described_class.new(tag: "b", attrs: {}, pos: 0, source: "[b]")

      expect(token.inspect).to eq("#<TagStartToken [b]>")
    end
  end
end
