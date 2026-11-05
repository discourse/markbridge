# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::LinkDestination do
  describe ".escape" do
    it "leaves a plain URL alone" do
      url = "https://example.com/a?b=c#d"

      expect(described_class.escape(url)).to be(url)
    end

    it "puts a backslash in front of every parenthesis" do
      expect(described_class.escape("a(b)c)")).to eq("a\\(b\\)c\\)")
    end

    it "doubles a backslash" do
      expect(described_class.escape("a\\b")).to eq("a\\\\b")
    end

    it "wraps a destination with whitespace in angle brackets" do
      expect(described_class.escape("Main Page")).to eq("<Main Page>")
      expect(described_class.escape("a\tb")).to eq("<a\tb>")
    end

    it "escapes and wraps a destination that needs both" do
      expect(described_class.escape("Main (Page)")).to eq("<Main \\(Page\\)>")
    end

    it "escapes angle brackets inside the wrapped destination, which would end it" do
      expect(described_class.escape("a b>c<d")).to eq("<a b\\>c\\<d>")
    end

    it "leaves angle brackets alone in a destination without whitespace" do
      expect(described_class.escape("a>b")).to eq("a>b")
    end

    it "returns nil for nil" do
      expect(described_class.escape(nil)).to be_nil
    end
  end
end
