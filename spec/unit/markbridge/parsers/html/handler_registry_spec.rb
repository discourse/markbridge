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

    it "coerces non-string tag names to string before downcasing" do
      registry.register(:B, handler)

      expect(registry["b"]).to eq(handler)
    end

    it "returns self for chaining" do
      result = registry.register("b", handler)

      expect(result).to eq(registry)
    end

    it "supports lambdas as handlers" do
      handler = ->(element:, parent:) { parent << "test" }
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

    it "coerces non-string tag names to string before downcasing" do
      registry.register("b", handler)

      expect(registry[:B]).to eq(handler)
    end
  end

  describe ".default" do
    let(:default_registry) { described_class.default }

    it "returns a HandlerRegistry" do
      expect(default_registry).to be_a(described_class)
    end

    {
      "b" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Bold],
      "strong" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Bold],
      "i" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Italic],
      "em" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Italic],
      "s" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Strikethrough],
      "strike" => [
        Markbridge::Parsers::HTML::Handlers::SimpleHandler,
        Markbridge::AST::Strikethrough,
      ],
      "del" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Strikethrough],
      "u" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Underline],
      "sup" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Superscript],
      "sub" => [Markbridge::Parsers::HTML::Handlers::SimpleHandler, Markbridge::AST::Subscript],
      "code" => [Markbridge::Parsers::HTML::Handlers::RawHandler, Markbridge::AST::Code],
      "pre" => [Markbridge::Parsers::HTML::Handlers::RawHandler, Markbridge::AST::Code],
      "tt" => [Markbridge::Parsers::HTML::Handlers::RawHandler, Markbridge::AST::Code],
      "a" => [Markbridge::Parsers::HTML::Handlers::UrlHandler, Markbridge::AST::Url],
      "img" => [Markbridge::Parsers::HTML::Handlers::ImageHandler, Markbridge::AST::Image],
      "blockquote" => [Markbridge::Parsers::HTML::Handlers::QuoteHandler, Markbridge::AST::Quote],
      "ul" => [Markbridge::Parsers::HTML::Handlers::ListHandler, Markbridge::AST::List],
      "ol" => [Markbridge::Parsers::HTML::Handlers::ListHandler, Markbridge::AST::List],
      "li" => [Markbridge::Parsers::HTML::Handlers::ListItemHandler, Markbridge::AST::ListItem],
      "table" => [Markbridge::Parsers::HTML::Handlers::TableHandler, Markbridge::AST::Table],
      "tr" => [Markbridge::Parsers::HTML::Handlers::TableRowHandler, Markbridge::AST::TableRow],
      "td" => [Markbridge::Parsers::HTML::Handlers::TableCellHandler, Markbridge::AST::TableCell],
      "th" => [Markbridge::Parsers::HTML::Handlers::TableCellHandler, Markbridge::AST::TableCell],
      "p" => [Markbridge::Parsers::HTML::Handlers::ParagraphHandler, Markbridge::AST::Paragraph],
    }.each do |tag, (handler_class, element_class)|
      it "registers #{handler_class.name.split("::").last} producing #{element_class.name.split("::").last} for <#{tag}>" do
        registered = default_registry[tag]
        expect(registered).to be_a(handler_class)
        if registered.respond_to?(:element_class)
          expect(registered.element_class).to eq(element_class)
        end
      end
    end

    # br and hr are inline lambdas, not handler instances
    it "registers a lambda for <br> that emits a LineBreak and returns nil" do
      parent = Markbridge::AST::Paragraph.new
      result = default_registry["br"].call(element: nil, parent:)

      # Assert exactly one child of the right type — `all(be_a(...))`
      # passes vacuously on empty arrays, so mutations that drop the
      # `parent << AST::LineBreak.new` would slip through.
      expect(parent.children.size).to eq(1)
      expect(parent.children.first).to be_a(Markbridge::AST::LineBreak)
      # Not a HorizontalRule — kills cross-lambda `.new` swaps.
      expect(parent.children.first).not_to be_a(Markbridge::AST::HorizontalRule)
      # Returns nil so the parser does NOT descend into children.
      expect(result).to be_nil
    end

    it "registers a lambda for <hr> that emits a HorizontalRule and returns nil" do
      parent = Markbridge::AST::Paragraph.new
      result = default_registry["hr"].call(element: nil, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children.first).to be_a(Markbridge::AST::HorizontalRule)
      expect(parent.children.first).not_to be_a(Markbridge::AST::LineBreak)
      expect(result).to be_nil
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

    it "returns the default registry unchanged when no block is given" do
      registry = described_class.build_from_default

      expect(registry).to be_a(described_class)
      expect(registry["b"]).to be_a(Markbridge::Parsers::HTML::Handlers::SimpleHandler)
    end
  end
end
