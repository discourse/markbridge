# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::HandlerRegistry do
  let(:registry) { described_class.new }

  describe "#register" do
    let(:handler) do
      h = instance_double(Markbridge::Parsers::BBCode::Handlers::SimpleHandler)
      allow(h).to receive(:element_class).and_return(Markbridge::AST::Bold)
      allow(h).to receive(:auto_closeable?).and_return(false)
      h
    end

    it "registers a handler for a tag name and element class" do
      registry.register("b", handler)

      expect(registry["b"]).to eq(handler)
      element = Markbridge::AST::Bold.new
      expect(registry.handler_for_element(element)).to eq(handler)
    end

    it "registers a handler for multiple tag names" do
      registry.register(%w[b bold strong], handler)

      expect(registry["b"]).to eq(handler)
      expect(registry["bold"]).to eq(handler)
      expect(registry["strong"]).to eq(handler)
    end

    it "normalizes tag names to lowercase" do
      registry.register("B", handler)

      expect(registry["b"]).to eq(handler)
      expect(registry["B"]).to eq(handler)
    end

    it "marks elements as auto-closeable when handler returns true" do
      auto_closeable_handler = instance_double(Markbridge::Parsers::BBCode::Handlers::SimpleHandler)
      allow(auto_closeable_handler).to receive(:element_class).and_return(Markbridge::AST::Bold)
      allow(auto_closeable_handler).to receive(:auto_closeable?).and_return(true)

      registry.register("b", auto_closeable_handler)

      expect(registry.auto_closeable?(Markbridge::AST::Bold)).to be true
    end

    it "returns self for chaining" do
      result = registry.register("b", handler)

      expect(result).to eq(registry)
    end
  end

  describe "#[]" do
    let(:handler) do
      h = instance_double(Markbridge::Parsers::BBCode::Handlers::SimpleHandler)
      allow(h).to receive(:element_class).and_return(Markbridge::AST::Bold)
      allow(h).to receive(:auto_closeable?).and_return(false)
      h
    end

    it "returns nil for unregistered tag" do
      expect(registry["unknown"]).to be_nil
    end

    it "returns handler for registered tag" do
      registry.register("b", handler)

      expect(registry["b"]).to eq(handler)
    end
  end

  describe "#handler_for_element" do
    let(:handler) do
      h = instance_double(Markbridge::Parsers::BBCode::Handlers::SimpleHandler)
      allow(h).to receive(:element_class).and_return(Markbridge::AST::Bold)
      allow(h).to receive(:auto_closeable?).and_return(false)
      h
    end

    it "returns nil for unregistered element class" do
      element = Markbridge::AST::Bold.new
      expect(registry.handler_for_element(element)).to be_nil
    end

    it "returns handler for registered element class" do
      registry.register("b", handler)

      element = Markbridge::AST::Bold.new
      expect(registry.handler_for_element(element)).to eq(handler)
    end
  end

  describe ".default" do
    let(:default_registry) { described_class.default }

    it "returns a HandlerRegistry" do
      expect(default_registry).to be_a(described_class)
    end

    it "registers bold tags" do
      expect(default_registry["b"]).not_to be_nil
      expect(default_registry["bold"]).not_to be_nil
      expect(default_registry["strong"]).not_to be_nil
    end

    it "registers italic tags" do
      expect(default_registry["i"]).not_to be_nil
      expect(default_registry["italic"]).not_to be_nil
      expect(default_registry["em"]).not_to be_nil
    end

    it "registers code tags" do
      expect(default_registry["code"]).not_to be_nil
      expect(default_registry["pre"]).not_to be_nil
    end

    it "registers url tags" do
      expect(default_registry["url"]).not_to be_nil
      expect(default_registry["link"]).not_to be_nil
    end

    it "registers attachment tags" do
      expect(default_registry["attach"]).not_to be_nil
      expect(default_registry["attachment"]).not_to be_nil
    end

    it "registers list tags" do
      expect(default_registry["list"]).not_to be_nil
      expect(default_registry["ul"]).not_to be_nil
      expect(default_registry["ol"]).not_to be_nil
    end

    it "registers list item tags" do
      expect(default_registry["*"]).not_to be_nil
      expect(default_registry["li"]).not_to be_nil
    end

    it "accepts custom closing_strategy" do
      custom_strategy = instance_double(Markbridge::Parsers::BBCode::ClosingStrategies::Strict)
      allow(custom_strategy).to receive(:handle_close)

      registry = described_class.default(closing_strategy: custom_strategy)

      # Verify the registry has the custom strategy (not testing handler.closing_strategy)
      expect(registry.instance_variable_get(:@closing_strategy)).to eq(custom_strategy)
    end
  end

  describe ".default_closing_strategy" do
    let(:registry) { described_class.new }

    it "returns a Reordering strategy" do
      strategy = described_class.default_closing_strategy(registry)
      expect(strategy).to be_a(Markbridge::Parsers::BBCode::ClosingStrategies::Reordering)
    end
  end
end
