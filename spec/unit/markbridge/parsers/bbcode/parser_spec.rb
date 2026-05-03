# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Parser do
  describe "#initialize" do
    it "initializes unknown_tags as a counting hash defaulting to 0" do
      parser = described_class.new

      expect(parser.unknown_tags).to be_empty
      expect(parser.unknown_tags["never-seen"]).to eq(0)
    end

    it "routes parsing through a custom handlers registry when one is passed" do
      custom = Markbridge::Parsers::BBCode::HandlerRegistry.new
      custom.register(
        "b",
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      result = described_class.new(handlers: custom).parse("[b]x[/b]")

      expect(result.children.first).to be_a(Markbridge::AST::Italic)
    end

    it "invokes the block with the default registry and uses the resulting handlers" do
      result =
        described_class
          .new do |r|
            r.register(
              "b",
              Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
            )
          end
          .parse("[b]x[/b]")

      expect(result.children.first).to be_a(Markbridge::AST::Italic)
    end

    it "falls back to the default registry when no block and no handlers are given" do
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

  describe "tag reconciliation" do
    let(:parser) { described_class.new }

    it "forwards the registry to opening handlers" do
      registry_seen = nil
      capture_handler =
        Class.new(Markbridge::Parsers::BBCode::Handlers::BaseHandler) do
          define_method(:on_open) do |token:, context:, registry:, tokens: nil|
            registry_seen = registry
          end
        end

      parser = described_class.new { |r| r.register("captureopen", capture_handler.new) }
      parser.parse("[captureopen]")

      expect(registry_seen).to be_a(Markbridge::Parsers::BBCode::HandlerRegistry)
    end

    it "forwards the registry to closing handlers" do
      registry_seen = nil
      capture_handler =
        Class.new(Markbridge::Parsers::BBCode::Handlers::BaseHandler) do
          define_method(:on_close) do |token:, context:, registry:, tokens: nil|
            registry_seen = registry
          end
        end

      parser = described_class.new { |r| r.register("captureclose", capture_handler.new) }
      parser.parse("[/captureclose]")

      expect(registry_seen).to be_a(Markbridge::Parsers::BBCode::HandlerRegistry)
    end

    it "forwards remaining tokens to a closing handler so reordering can consume them" do
      # [b][i]text[/b][/i]: reordering should let the [/i] be consumed when [/b] closes,
      # producing properly-nested Bold > Italic. Without forwarding tokens, the [/i]
      # leaks out as text.
      doc = parser.parse("[b][i]text[/b][/i]")

      bold = doc.children.first
      expect(bold).to be_a(Markbridge::AST::Bold)
      italic = bold.children.first
      expect(italic).to be_a(Markbridge::AST::Italic)
      expect(italic.children.first.text).to eq("text")
      # No leaked [/i] text after Bold
      expect(doc.children.size).to eq(1)
    end
  end

  describe "diagnostic counters" do
    let(:parser) { described_class.new }

    it "exposes auto_closed_tags_count from the parser state" do
      parser.parse("[b][i]text[/b][/i]")

      expect(parser.auto_closed_tags_count).to be > 0
    end

    it "exposes depth_exceeded_count from the parser state" do
      parser.parse("[b]" * 200 + "x" + "[/b]" * 200)

      expect(parser.depth_exceeded_count).to be > 0
    end

    it "exposes unclosed_raw_tags from the parser state" do
      parser.parse("[code]unterminated")

      expect(parser.unclosed_raw_tags).to include("code")
    end

    it "resets diagnostic counters between parses" do
      parser.parse("[b]" * 200 + "x" + "[/b]" * 200)
      expect(parser.depth_exceeded_count).to be > 0

      parser.parse("plain text")
      expect(parser.depth_exceeded_count).to eq(0)
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

    it "collapses consecutive Unicode line separators into a single newline" do
      result = parser.parse("a\u2028\u2028b")

      expect(result.children.first.text).to eq("a\nb")
    end
  end
end
