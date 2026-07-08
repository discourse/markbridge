# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::MediaWiki::InlineTagRegistry do
  describe "#register and #[]" do
    it "registers and retrieves a formatting tag" do
      registry = described_class.new
      registry.register("s", :formatting, Markbridge::AST::Strikethrough)

      entry = registry["s"]
      expect(entry.type).to eq(:formatting)
      expect(entry.element_class).to eq(Markbridge::AST::Strikethrough)
    end

    it "registers and retrieves a raw tag" do
      registry = described_class.new
      registry.register("code", :raw, Markbridge::AST::Code)

      entry = registry["code"]
      expect(entry.type).to eq(:raw)
      expect(entry.element_class).to eq(Markbridge::AST::Code)
    end

    it "registers and retrieves a self-closing tag" do
      registry = described_class.new
      registry.register("br", :self_closing, Markbridge::AST::LineBreak)

      entry = registry["br"]
      expect(entry.type).to eq(:self_closing)
      expect(entry.element_class).to eq(Markbridge::AST::LineBreak)
    end

    it "is case-insensitive" do
      registry = described_class.new
      registry.register("CODE", :raw, Markbridge::AST::Code)

      expect(registry["code"]).not_to be_nil
      expect(registry["CODE"]).not_to be_nil
    end

    it "returns nil for unregistered tags" do
      registry = described_class.new
      expect(registry["unknown"]).to be_nil
    end

    it "allows nil element_class for raw tags" do
      registry = described_class.new
      registry.register("nowiki", :raw, nil)

      entry = registry["nowiki"]
      expect(entry.type).to eq(:raw)
      expect(entry.element_class).to be_nil
    end

    it "raises for invalid type, naming the valid types and the offending value" do
      registry = described_class.new
      expect { registry.register("x", :invalid, Markbridge::AST::Bold) }.to raise_error(
        ArgumentError,
        "type must be one of [:raw, :formatting, :self_closing], got :invalid",
      )
    end

    it "returns self for chaining" do
      registry = described_class.new
      result = registry.register("s", :formatting, Markbridge::AST::Strikethrough)
      expect(result).to be(registry)
    end
  end

  describe "#known?" do
    it "returns true for registered tags" do
      registry = described_class.new
      registry.register("code", :raw, Markbridge::AST::Code)

      expect(registry.known?("code")).to be true
    end

    it "returns false for unregistered tags" do
      registry = described_class.new
      expect(registry.known?("span")).to be false
    end

    it "is case-insensitive" do
      registry = described_class.new
      registry.register("code", :raw, Markbridge::AST::Code)

      expect(registry.known?("CODE")).to be true
    end
  end

  describe ".default" do
    subject(:registry) { described_class.default }

    it "includes nowiki as raw with nil element_class" do
      entry = registry["nowiki"]
      expect(entry.type).to eq(:raw)
      expect(entry.element_class).to be_nil
    end

    it "includes code as raw" do
      entry = registry["code"]
      expect(entry.type).to eq(:raw)
      expect(entry.element_class).to eq(Markbridge::AST::Code)
    end

    it "includes pre as raw" do
      entry = registry["pre"]
      expect(entry.type).to eq(:raw)
      expect(entry.element_class).to eq(Markbridge::AST::Code)
    end

    it "includes s as formatting" do
      entry = registry["s"]
      expect(entry.type).to eq(:formatting)
      expect(entry.element_class).to eq(Markbridge::AST::Strikethrough)
    end

    it "includes del as formatting" do
      entry = registry["del"]
      expect(entry.type).to eq(:formatting)
      expect(entry.element_class).to eq(Markbridge::AST::Strikethrough)
    end

    it "includes u as formatting" do
      entry = registry["u"]
      expect(entry.type).to eq(:formatting)
      expect(entry.element_class).to eq(Markbridge::AST::Underline)
    end

    it "includes ins as formatting" do
      entry = registry["ins"]
      expect(entry.type).to eq(:formatting)
      expect(entry.element_class).to eq(Markbridge::AST::Underline)
    end

    it "includes sup as formatting" do
      entry = registry["sup"]
      expect(entry.type).to eq(:formatting)
      expect(entry.element_class).to eq(Markbridge::AST::Superscript)
    end

    it "includes sub as formatting" do
      entry = registry["sub"]
      expect(entry.type).to eq(:formatting)
      expect(entry.element_class).to eq(Markbridge::AST::Subscript)
    end

    it "includes br as self_closing" do
      entry = registry["br"]
      expect(entry.type).to eq(:self_closing)
      expect(entry.element_class).to eq(Markbridge::AST::LineBreak)
    end
  end

  describe ".build_from_default" do
    it "returns a registry with default entries" do
      registry = described_class.build_from_default
      expect(registry["code"]).not_to be_nil
      expect(registry["br"]).not_to be_nil
    end

    it "allows customization via block" do
      registry =
        described_class.build_from_default do |r|
          r.register("mark", :formatting, Markbridge::AST::Bold)
        end

      expect(registry["mark"]).not_to be_nil
      expect(registry["mark"].type).to eq(:formatting)
      expect(registry["mark"].element_class).to eq(Markbridge::AST::Bold)
    end

    it "allows overriding default entries" do
      registry =
        described_class.build_from_default do |r|
          r.register("code", :formatting, Markbridge::AST::Bold)
        end

      expect(registry["code"].type).to eq(:formatting)
      expect(registry["code"].element_class).to eq(Markbridge::AST::Bold)
    end
  end

  describe ".shared_default" do
    it "returns the same instance on every call" do
      expect(described_class.shared_default).to be(described_class.shared_default)
    end

    it "is frozen" do
      expect(described_class.shared_default).to be_frozen
    end

    it "resolves the default tags" do
      expect(described_class.shared_default["code"].element_class).to eq(Markbridge::AST::Code)
    end

    it "is a different instance from .default" do
      expect(described_class.shared_default).not_to be(described_class.default)
    end
  end

  describe "#freeze" do
    it "makes register raise instead of silently mutating shared state" do
      frozen = described_class.new.freeze

      expect { frozen.register("mark", :formatting, Markbridge::AST::Bold) }.to raise_error(
        FrozenError,
      )
    end

    it "returns self" do
      registry = described_class.new

      expect(registry.freeze).to be(registry)
    end
  end
end
