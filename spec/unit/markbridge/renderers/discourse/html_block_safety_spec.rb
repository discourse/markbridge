# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::HtmlBlockSafety do
  describe ".safe?" do
    it "accepts an empty string" do
      expect(described_class.safe?("")).to be(true)
    end

    it "accepts plain text without Markdown sigils" do
      expect(described_class.safe?("plain text")).to be(true)
    end

    it "accepts a raw HTML fragment" do
      expect(described_class.safe?("<strong>x</strong>")).to be(true)
    end

    it "rejects emphasis stars" do
      expect(described_class.safe?("**x**")).to be(false)
    end

    it "rejects underscores" do
      expect(described_class.safe?("_x_")).to be(false)
    end

    it "rejects tildes" do
      expect(described_class.safe?("~x~")).to be(false)
    end

    it "rejects a link middle" do
      expect(described_class.safe?("[x](https://example.com)")).to be(false)
    end

    it "accepts a lone closing bracket" do
      expect(described_class.safe?("a] b")).to be(true)
    end

    it "accepts a lone opening parenthesis" do
      expect(described_class.safe?("a (b)")).to be(true)
    end

    it "accepts Markdown inside a blank-line wrapped island" do
      expect(described_class.safe?("\n\n**x**\n\n")).to be(true)
    end

    it "rejects Markdown when only the leading blank line is present" do
      expect(described_class.safe?("\n\n**x**")).to be(false)
    end

    it "rejects Markdown when only the trailing blank line is present" do
      expect(described_class.safe?("**x**\n\n")).to be(false)
    end

    it "rejects Markdown when the island starts with a single newline" do
      expect(described_class.safe?("\n**x**\n\n")).to be(false)
    end

    it "rejects Markdown when the island ends with a single newline" do
      expect(described_class.safe?("\n\n**x**\n")).to be(false)
    end
  end
end
