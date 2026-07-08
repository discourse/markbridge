# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::HandlerRegistry do
  let(:registry) { described_class.new }

  def fake_handler(element_class: Markbridge::AST::Bold, auto_closeable: false)
    h = instance_double(Markbridge::Parsers::BBCode::Handlers::SimpleHandler)
    allow(h).to receive(:element_class).and_return(element_class)
    allow(h).to receive(:auto_closeable?).and_return(auto_closeable)
    h
  end

  describe "#initialize" do
    it "starts with no registered tag handler" do
      expect(registry["b"]).to be_nil
    end

    it "starts with no element-class handler mapping" do
      expect(registry.handler_for_element(Markbridge::AST::Bold.new)).to be_nil
    end

    it "starts with no auto-closeable element classes" do
      expect(registry.auto_closeable?(Markbridge::AST::Bold)).to be false
    end

    it "starts with a nil closing_strategy that close_element silently no-ops on" do
      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      expect { registry.close_element(token:, context: nil) }.not_to raise_error
    end

    it "accepts a closing_strategy at construction time" do
      strategy = instance_double(Markbridge::Parsers::BBCode::ClosingStrategies::Strict)
      allow(strategy).to receive(:handle_close)
      registry = described_class.new(closing_strategy: strategy)
      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      registry.close_element(token:, context: :ctx, tokens: :tk)

      expect(strategy).to have_received(:handle_close).with(
        token:,
        context: :ctx,
        registry:,
        tokens: :tk,
      )
    end
  end

  describe "#register" do
    it "registers a handler under the lowercased tag name" do
      registry.register("B", fake_handler)

      expect(registry["b"]).not_to be_nil
    end

    it "registers a handler for multiple tag names" do
      handler = fake_handler
      registry.register(%w[b bold strong], handler)

      expect(registry["b"]).to eq(handler)
      expect(registry["bold"]).to eq(handler)
      expect(registry["strong"]).to eq(handler)
    end

    it "associates the handler with its element_class" do
      handler = fake_handler(element_class: Markbridge::AST::Italic)
      registry.register("i", handler)

      expect(registry.handler_for_element(Markbridge::AST::Italic.new)).to eq(handler)
    end

    it "marks the element as auto-closeable when handler.auto_closeable? is true" do
      registry.register("b", fake_handler(auto_closeable: true))

      expect(registry.auto_closeable?(Markbridge::AST::Bold)).to be true
    end

    it "does not mark the element as auto-closeable when handler.auto_closeable? is false" do
      registry.register("b", fake_handler(auto_closeable: false))

      expect(registry.auto_closeable?(Markbridge::AST::Bold)).to be false
    end

    it "returns self for chaining" do
      expect(registry.register("b", fake_handler)).to eq(registry)
    end

    it "accepts a single string (not just an array)" do
      handler = fake_handler
      registry.register("only", handler)

      expect(registry["only"]).to eq(handler)
    end

    it "coerces non-string tag names (e.g., a symbol) to string before downcasing" do
      handler = fake_handler
      registry.register(:CUSTOM, handler)

      expect(registry["custom"]).to eq(handler)
    end
  end

  describe "#[]" do
    it "returns nil for an unregistered tag" do
      expect(registry["unknown"]).to be_nil
    end

    it "returns the handler for a registered tag" do
      handler = fake_handler
      registry.register("b", handler)

      expect(registry["b"]).to eq(handler)
    end

    it "is case-insensitive" do
      handler = fake_handler
      registry.register("b", handler)

      expect(registry["B"]).to eq(handler)
    end

    it "coerces non-string arguments to string before lookup" do
      handler = fake_handler
      registry.register("b", handler)

      expect(registry[:b]).to eq(handler)
    end
  end

  describe "#handler_for_element" do
    it "returns nil for an unregistered element class" do
      expect(registry.handler_for_element(Markbridge::AST::Bold.new)).to be_nil
    end

    it "returns the handler keyed by element class identity" do
      handler = fake_handler(element_class: Markbridge::AST::Italic)
      registry.register("i", handler)

      expect(registry.handler_for_element(Markbridge::AST::Italic.new)).to eq(handler)
    end
  end

  describe "#auto_closeable?" do
    it "returns false for an unregistered class" do
      expect(registry.auto_closeable?(Markbridge::AST::Bold)).to be false
    end

    it "returns true after registering a handler that opts in" do
      registry.register("b", fake_handler(auto_closeable: true))

      expect(registry.auto_closeable?(Markbridge::AST::Bold)).to be true
    end
  end

  describe "#each" do
    it "yields registered (tag_name, handler) pairs" do
      handler = fake_handler
      registry.register("b", handler)
      registry.register("i", fake_handler(element_class: Markbridge::AST::Italic))

      expect(registry.each.to_a.map(&:first)).to eq(%w[b i])
    end

    it "preserves registration order" do
      registry.register("z", fake_handler(element_class: Markbridge::AST::Italic))
      registry.register("a", fake_handler)

      expect(registry.map(&:first)).to eq(%w[z a])
    end

    it "returns an Enumerator when no block is given" do
      expect(registry.each).to be_a(Enumerator)
    end

    it "yields nothing on an empty registry" do
      yielded = []
      registry.each { |pair| yielded << pair }

      expect(yielded).to be_empty
    end

    it "exposes Enumerable conveniences (count, to_h)" do
      handler = fake_handler
      registry.register("b", handler)

      expect(registry.count).to eq(1)
      expect(registry.to_h).to eq({ "b" => handler })
    end
  end

  describe "#close_element" do
    let(:strategy) { instance_double(Markbridge::Parsers::BBCode::ClosingStrategies::Strict) }
    let(:token) { Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]") }

    before do
      allow(strategy).to receive(:handle_close)
      registry.closing_strategy = strategy
    end

    it "forwards token, context, registry-self, and tokens to the closing strategy" do
      registry.close_element(token:, context: :ctx, tokens: :tk)

      expect(strategy).to have_received(:handle_close).with(
        token:,
        context: :ctx,
        registry:,
        tokens: :tk,
      )
    end

    it "defaults tokens to nil when omitted" do
      registry.close_element(token:, context: :ctx)

      expect(strategy).to have_received(:handle_close).with(
        token:,
        context: :ctx,
        registry:,
        tokens: nil,
      )
    end

    it "no-ops silently when closing_strategy is nil" do
      registry.closing_strategy = nil

      expect { registry.close_element(token:, context: :ctx) }.not_to raise_error
    end
  end

  describe ".default" do
    let(:default_registry) { described_class.default }

    it "returns a HandlerRegistry" do
      expect(default_registry).to be_a(described_class)
    end

    {
      "b" => [Markbridge::Parsers::BBCode::Handlers::SimpleHandler, Markbridge::AST::Bold, true],
      "bold" => [Markbridge::Parsers::BBCode::Handlers::SimpleHandler, Markbridge::AST::Bold, true],
      "strong" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Bold,
        true,
      ],
      "i" => [Markbridge::Parsers::BBCode::Handlers::SimpleHandler, Markbridge::AST::Italic, true],
      "italic" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Italic,
        true,
      ],
      "em" => [Markbridge::Parsers::BBCode::Handlers::SimpleHandler, Markbridge::AST::Italic, true],
      "s" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Strikethrough,
        true,
      ],
      "strike" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Strikethrough,
        true,
      ],
      "del" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Strikethrough,
        true,
      ],
      "u" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Underline,
        true,
      ],
      "underline" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Underline,
        true,
      ],
      "sup" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Superscript,
        true,
      ],
      "sub" => [
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler,
        Markbridge::AST::Subscript,
        true,
      ],
      "code" => [Markbridge::Parsers::BBCode::Handlers::CodeHandler, Markbridge::AST::Code, false],
      "pre" => [Markbridge::Parsers::BBCode::Handlers::CodeHandler, Markbridge::AST::Code, false],
      "tt" => [Markbridge::Parsers::BBCode::Handlers::CodeHandler, Markbridge::AST::Code, false],
      "img" => [Markbridge::Parsers::BBCode::Handlers::ImageHandler, Markbridge::AST::Image, false],
      "attach" => [
        Markbridge::Parsers::BBCode::Handlers::AttachmentHandler,
        Markbridge::AST::Attachment,
        false,
      ],
      "attachment" => [
        Markbridge::Parsers::BBCode::Handlers::AttachmentHandler,
        Markbridge::AST::Attachment,
        false,
      ],
      "url" => [Markbridge::Parsers::BBCode::Handlers::UrlHandler, Markbridge::AST::Url, false],
      "link" => [Markbridge::Parsers::BBCode::Handlers::UrlHandler, Markbridge::AST::Url, false],
      "iurl" => [Markbridge::Parsers::BBCode::Handlers::UrlHandler, Markbridge::AST::Url, false],
      "email" => [
        Markbridge::Parsers::BBCode::Handlers::EmailHandler,
        Markbridge::AST::Email,
        false,
      ],
      "quote" => [
        Markbridge::Parsers::BBCode::Handlers::QuoteHandler,
        Markbridge::AST::Quote,
        false,
      ],
      "spoiler" => [
        Markbridge::Parsers::BBCode::Handlers::SpoilerHandler,
        Markbridge::AST::Spoiler,
        false,
      ],
      "hide" => [
        Markbridge::Parsers::BBCode::Handlers::SpoilerHandler,
        Markbridge::AST::Spoiler,
        false,
      ],
      "color" => [
        Markbridge::Parsers::BBCode::Handlers::ColorHandler,
        Markbridge::AST::Color,
        true,
      ],
      "size" => [Markbridge::Parsers::BBCode::Handlers::SizeHandler, Markbridge::AST::Size, true],
      "center" => [
        Markbridge::Parsers::BBCode::Handlers::AlignHandler,
        Markbridge::AST::Align,
        false,
      ],
      "left" => [
        Markbridge::Parsers::BBCode::Handlers::AlignHandler,
        Markbridge::AST::Align,
        false,
      ],
      "right" => [
        Markbridge::Parsers::BBCode::Handlers::AlignHandler,
        Markbridge::AST::Align,
        false,
      ],
      "justify" => [
        Markbridge::Parsers::BBCode::Handlers::AlignHandler,
        Markbridge::AST::Align,
        false,
      ],
      "br" => [
        Markbridge::Parsers::BBCode::Handlers::SelfClosingHandler,
        Markbridge::AST::LineBreak,
        false,
      ],
      "hr" => [
        Markbridge::Parsers::BBCode::Handlers::SelfClosingHandler,
        Markbridge::AST::HorizontalRule,
        false,
      ],
      "list" => [Markbridge::Parsers::BBCode::Handlers::ListHandler, Markbridge::AST::List, false],
      "ul" => [Markbridge::Parsers::BBCode::Handlers::ListHandler, Markbridge::AST::List, false],
      "ol" => [Markbridge::Parsers::BBCode::Handlers::ListHandler, Markbridge::AST::List, false],
      "ulist" => [Markbridge::Parsers::BBCode::Handlers::ListHandler, Markbridge::AST::List, false],
      "olist" => [Markbridge::Parsers::BBCode::Handlers::ListHandler, Markbridge::AST::List, false],
      "*" => [
        Markbridge::Parsers::BBCode::Handlers::ListItemHandler,
        Markbridge::AST::ListItem,
        false,
      ],
      "li" => [
        Markbridge::Parsers::BBCode::Handlers::ListItemHandler,
        Markbridge::AST::ListItem,
        false,
      ],
      "." => [
        Markbridge::Parsers::BBCode::Handlers::ListItemHandler,
        Markbridge::AST::ListItem,
        false,
      ],
      "table" => [
        Markbridge::Parsers::BBCode::Handlers::TableHandler,
        Markbridge::AST::Table,
        false,
      ],
      "tr" => [
        Markbridge::Parsers::BBCode::Handlers::TableRowHandler,
        Markbridge::AST::TableRow,
        false,
      ],
      "td" => [
        Markbridge::Parsers::BBCode::Handlers::TableCellHandler,
        Markbridge::AST::TableCell,
        false,
      ],
      "th" => [
        Markbridge::Parsers::BBCode::Handlers::TableCellHandler,
        Markbridge::AST::TableCell,
        false,
      ],
    }.each do |tag, (handler_class, element_class, auto_closeable)|
      it "registers #{handler_class.name.split("::").last} producing #{element_class.name.split("::").last} for [#{tag}] (auto_closeable: #{auto_closeable})" do
        registered = default_registry[tag]
        expect(registered).to be_a(handler_class)
        expect(registered.element_class).to eq(element_class)
        expect(default_registry.auto_closeable?(element_class)).to eq(auto_closeable)
      end
    end

    it "uses the default Reordering closing strategy bound to the registry itself" do
      strategy = default_registry.instance_variable_get(:@closing_strategy)
      reconciler = strategy.instance_variable_get(:@reconciler)

      expect(strategy).to be_a(Markbridge::Parsers::BBCode::ClosingStrategies::Reordering)
      expect(reconciler.instance_variable_get(:@registry)).to eq(default_registry)
    end

    it "uses an explicit closing_strategy when one is provided" do
      custom = instance_double(Markbridge::Parsers::BBCode::ClosingStrategies::Strict)
      registry = described_class.default(closing_strategy: custom)

      expect(registry.instance_variable_get(:@closing_strategy)).to eq(custom)
    end
  end

  describe ".build_from_default" do
    it "yields the default registry for customization" do
      yielded = nil
      described_class.build_from_default { |r| yielded = r }

      expect(yielded).to be_a(described_class)
      expect(yielded["b"]).not_to be_nil
    end

    it "returns the default registry unchanged when no block is given" do
      registry = described_class.build_from_default

      expect(registry).to be_a(described_class)
      expect(registry["b"]).not_to be_nil
    end

    it "permits the block to register additional handlers" do
      registry =
        described_class.build_from_default do |r|
          r.register(
            "custom",
            Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Bold),
          )
        end

      expect(registry["custom"]).not_to be_nil
    end
  end

  describe ".default_closing_strategy" do
    it "returns a Reordering strategy wrapping a TagReconciler bound to the registry" do
      strategy = described_class.default_closing_strategy(registry)

      expect(strategy).to be_a(Markbridge::Parsers::BBCode::ClosingStrategies::Reordering)
      reconciler = strategy.instance_variable_get(:@reconciler)
      expect(reconciler).to be_a(Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler)
      expect(reconciler.instance_variable_get(:@registry)).to eq(registry)
    end
  end

  describe "#overlay" do
    let(:registry) { described_class.default }

    it "yields the previously bound handler so a wrapper can delegate to it" do
      seen = nil
      registry.overlay("url") do |previous|
        seen = previous
        previous
      end

      expect(seen).to be_a(Markbridge::Parsers::BBCode::Handlers::UrlHandler)
    end

    it "yields nil when no handler was previously bound" do
      seen = :unset
      registry.overlay("brand-new-tag") do |previous|
        seen = previous
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Bold)
      end

      expect(seen).to be_nil
    end

    it "registers whatever the block returns" do
      replacement =
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic)

      registry.overlay("url") { |_| replacement }

      expect(registry["url"]).to be(replacement)
    end

    it "applies to every tag name in the array" do
      replacement =
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic)

      registry.overlay(%w[url link iurl]) { |_| replacement }

      expect(registry["url"]).to be(replacement)
      expect(registry["link"]).to be(replacement)
      expect(registry["iurl"]).to be(replacement)
    end

    it "yields each name's previously-bound handler when called with an Array" do
      yielded = []
      registry.overlay(%w[url link iurl]) do |previous|
        yielded << previous
        previous
      end

      expect(yielded.size).to eq(3)
      yielded.each do |handler|
        expect(handler).to be_a(Markbridge::Parsers::BBCode::Handlers::UrlHandler)
      end
    end

    it "returns self for chaining" do
      result = registry.overlay("url") { |p| p }
      expect(result).to be(registry)
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
      handler = described_class.shared_default["b"]

      expect(handler.element_class).to eq(Markbridge::AST::Bold)
    end

    it "has a closing strategy wired up" do
      registry = described_class.shared_default
      document = Markbridge::AST::Document.new
      context = Markbridge::Parsers::BBCode::ParserState.new(document)
      context.push(Markbridge::AST::Bold.new)
      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 3, source: "[/b]")

      registry.close_element(token:, context:)

      expect(context.current).to be(document)
    end

    it "is a different instance from .default" do
      expect(described_class.shared_default).not_to be(described_class.default)
    end
  end

  describe "#freeze" do
    it "makes register raise instead of silently mutating shared state" do
      frozen = described_class.new.freeze

      expect { frozen.register("b", fake_handler) }.to raise_error(FrozenError)
    end

    it "makes closing_strategy= raise" do
      frozen = described_class.new.freeze

      expect { frozen.closing_strategy = nil }.to raise_error(FrozenError)
    end

    it "returns self" do
      registry = described_class.new

      expect(registry.freeze).to be(registry)
    end
  end
end
