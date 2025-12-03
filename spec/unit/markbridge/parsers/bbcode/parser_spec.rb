# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Parser do
  describe "#initialize" do
    it "accepts custom handlers" do
      registry = Markbridge::Parsers::BBCode::HandlerRegistry.new
      parser = described_class.new(handlers: registry)
      expect(parser).to be_a(described_class)
    end

    it "uses default handlers when none provided" do
      parser = described_class.new
      expect(parser).to be_a(described_class)
    end

    it "can parse BBCode with default handlers" do
      parser = described_class.new
      result = parser.parse("[b]bold text[/b]")
      expect(result).to be_a(Markbridge::AST::Document)
      expect(result.children.first).to be_a(Markbridge::AST::Bold)
      expect(result.children.first.children.first.text).to eq("bold text")
    end
  end

  describe "#unknown_tags" do
    let(:parser) { described_class.new }

    it "tracks unknown tags" do
      parser.parse("[unknown]text[/unknown]")
      expect(parser.unknown_tags["unknown"]).to eq(2)
    end

    it "clears unknown_tags between parses" do
      parser.parse("[unknown]text[/unknown]")
      expect(parser.unknown_tags["unknown"]).to eq(2)
      parser.parse("plain text")
      expect(parser.unknown_tags).to be_empty
    end
  end

  describe "line ending normalization" do
    let(:parser) { described_class.new }

    it "normalizes CRLF line endings" do
      result = parser.parse("line1\r\nline2")
      expect(result.children.first.text).to eq("line1\nline2")
    end

    it "normalizes CR line endings" do
      result = parser.parse("line1\rline2")
      expect(result.children.first.text).to eq("line1\nline2")
    end

    it "normalizes mixed line endings" do
      result = parser.parse("line1\r\nline2\rline3\nline4")
      expect(result.children.first.text).to eq("line1\nline2\nline3\nline4")
    end

    it "normalizes Unicode line separators" do
      result = parser.parse("line1\u2028line2\u2029line3")
      expect(result.children.first.text).to eq("line1\nline2\nline3")
    end
  end
end
