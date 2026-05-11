# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::HandlerRegistry do
  let(:registry) { described_class.new }
  let(:handler) { instance_double(Markbridge::Parsers::HTML::Handlers::BaseHandler) }

  describe "#block_level_tags" do
    it "seeds with HTML5 block-level tags" do
      expect(registry.block_level_tags).to include("p", "div", "blockquote", "h1", "ul", "table")
    end

    it "exposes a mutable Set that consumers can extend" do
      registry.block_level_tags << "my-block"

      expect(registry.block_level_tags).to include("my-block")
    end

    it "exposes a mutable Set that consumers can prune" do
      registry.block_level_tags.delete("hr")

      expect(registry.block_level_tags).not_to include("hr")
    end

    it "isolates instances — mutating one registry does not affect another" do
      registry.block_level_tags << "my-block"

      expect(described_class.new.block_level_tags).not_to include("my-block")
    end
  end

  describe "#whitespace_preserving_tags" do
    it "seeds with HTML's whitespace-preserving tags" do
      expect(registry.whitespace_preserving_tags).to include("pre", "code", "textarea", "tt")
    end

    it "exposes a mutable Set that consumers can extend" do
      registry.whitespace_preserving_tags << "code-snippet"

      expect(registry.whitespace_preserving_tags).to include("code-snippet")
    end

    it "isolates instances — mutating one registry does not affect another" do
      registry.whitespace_preserving_tags << "code-snippet"

      expect(described_class.new.whitespace_preserving_tags).not_to include("code-snippet")
    end
  end

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

    # SpanHandler is conditional on the style attribute, so it has no
    # fixed element_class — it can't be slotted into the data-driven
    # table above.
    it "registers SpanHandler for <span>" do
      registered = default_registry["span"]

      expect(registered).to be_a(Markbridge::Parsers::HTML::Handlers::SpanHandler)
    end

    it "registers VoidHandler for <br> producing AST::LineBreak" do
      registered = default_registry["br"]

      expect(registered).to be_a(Markbridge::Parsers::HTML::Handlers::VoidHandler)
      expect(registered.element_class).to eq(Markbridge::AST::LineBreak)
    end

    it "registers VoidHandler for <hr> producing AST::HorizontalRule" do
      registered = default_registry["hr"]

      expect(registered).to be_a(Markbridge::Parsers::HTML::Handlers::VoidHandler)
      expect(registered.element_class).to eq(Markbridge::AST::HorizontalRule)
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
