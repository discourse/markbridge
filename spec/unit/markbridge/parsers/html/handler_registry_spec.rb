# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::HandlerRegistry do
  let(:registry) { described_class.new }
  let(:handler) { instance_double(Markbridge::Parsers::HTML::Handlers::BaseHandler) }

  describe "#register" do
    it "registers a handler for a single tag" do
      registry.register("b", handler)

      expect(registry["b"]).to eq(handler)
    end

    it "registers a handler for multiple tags" do
      registry.register(%w[b strong], handler)

      expect(registry["b"]).to eq(handler)
      expect(registry["strong"]).to eq(handler)
    end

    it "normalizes tag names to lowercase" do
      registry.register("BOLD", handler)

      expect(registry["bold"]).to eq(handler)
      expect(registry["BOLD"]).to eq(handler)
    end

    it "returns self for chaining" do
      result = registry.register("b", handler)

      expect(result).to eq(registry)
    end

    it "supports lambdas as handlers" do
      handler = ->(element:, parent:, processor:) { parent << "test" }
      registry.register("br", handler)

      expect(registry["br"]).to eq(handler)
    end
  end

  describe "#[]" do
    it "returns nil for unregistered tag" do
      expect(registry["unknown"]).to be_nil
    end

    it "returns handler for registered tag" do
      registry.register("b", handler)

      expect(registry["b"]).to eq(handler)
    end

    it "handles case-insensitive lookups" do
      registry.register("bold", handler)

      expect(registry["BOLD"]).to eq(handler)
      expect(registry["Bold"]).to eq(handler)
    end
  end

  describe ".default" do
    let(:default_registry) { described_class.default }

    it "returns a HandlerRegistry" do
      expect(default_registry).to be_a(described_class)
    end

    it "registers bold tags" do
      expect(default_registry["b"]).not_to be_nil
      expect(default_registry["strong"]).not_to be_nil
    end

    it "registers italic tags" do
      expect(default_registry["i"]).not_to be_nil
      expect(default_registry["em"]).not_to be_nil
    end

    it "registers strikethrough tags" do
      expect(default_registry["s"]).not_to be_nil
      expect(default_registry["strike"]).not_to be_nil
      expect(default_registry["del"]).not_to be_nil
    end

    it "registers underline tag" do
      expect(default_registry["u"]).not_to be_nil
    end

    it "registers superscript and subscript" do
      expect(default_registry["sup"]).not_to be_nil
      expect(default_registry["sub"]).not_to be_nil
    end

    it "registers code tags" do
      expect(default_registry["code"]).not_to be_nil
      expect(default_registry["pre"]).not_to be_nil
      expect(default_registry["tt"]).not_to be_nil
    end

    it "registers link tag" do
      expect(default_registry["a"]).not_to be_nil
    end

    it "registers image tag" do
      expect(default_registry["img"]).not_to be_nil
    end

    it "registers blockquote tag" do
      expect(default_registry["blockquote"]).not_to be_nil
    end

    it "registers void element tags" do
      expect(default_registry["br"]).not_to be_nil
      expect(default_registry["hr"]).not_to be_nil
    end

    it "registers list tags" do
      expect(default_registry["ul"]).not_to be_nil
      expect(default_registry["ol"]).not_to be_nil
      expect(default_registry["li"]).not_to be_nil
    end

    it "registers paragraph tag" do
      expect(default_registry["p"]).not_to be_nil
    end

    it "uses lambdas for void elements" do
      expect(default_registry["br"]).to respond_to(:call)
      expect(default_registry["hr"]).to respond_to(:call)
    end
  end

  describe ".build_from_default" do
    it "yields the registry for customization" do
      expect { |b| described_class.build_from_default(&b) }.to yield_with_args(
        Markbridge::Parsers::HTML::HandlerRegistry,
      )
    end

    it "allows customization of default registry" do
      custom_handler = instance_double(Markbridge::Parsers::HTML::Handlers::BaseHandler)
      registry = described_class.build_from_default { |r| r.register("custom", custom_handler) }

      expect(registry["custom"]).to eq(custom_handler)
      expect(registry["b"]).not_to be_nil # Still has defaults
    end
  end
end
