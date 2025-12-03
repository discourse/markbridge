# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::BaseHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }
  let(:registry) do
    reg = Markbridge::Parsers::BBCode::HandlerRegistry.new
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry: reg)
    closing_strategy = Markbridge::Parsers::BBCode::ClosingStrategies::Reordering.new(reconciler)
    reg.closing_strategy = closing_strategy
    reg
  end

  describe "#on_open" do
    it "has no default behavior" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "test",
          attrs: {
          },
          pos: 0,
          source: "[test]",
        )

      result = handler.on_open(token:, context:, registry:)

      expect(result).to be_nil
      expect(document.children).to be_empty
      expect(context.current).to eq(document)
    end
  end

  describe "#on_close" do
    context "when current element is not an Element" do
      it "does nothing when current is Document" do
        token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "test", pos: 0, source: "[/test]")

        expect(context.current).to eq(document)

        handler.on_close(token:, context:, registry:)

        expect(context.current).to eq(document)
        expect(document.children).to be_empty
      end
    end

    context "when current element matches the closing tag" do
      it "pops the element from the stack" do
        # Setup: create a bold handler and element
        bold_handler =
          Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Bold)
        registry.register("b", bold_handler)

        # Open a bold tag
        open_token =
          Markbridge::Parsers::BBCode::TagStartToken.new(tag: "b", attrs: {}, pos: 0, source: "[b]")
        bold_handler.on_open(token: open_token, context:, registry:)

        bold_element = context.current
        expect(bold_element).to be_a(Markbridge::AST::Bold)

        # Close the bold tag
        close_token =
          Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 10, source: "[/b]")
        bold_handler.on_close(token: close_token, context:, registry:)

        # Should pop back to document
        expect(context.current).to eq(document)
        expect(document.children).to eq([bold_element])
      end
    end

    context "when closing tag doesn't match current element" do
      it "treats the closing tag as text" do
        # Setup: create bold and italic handlers
        bold_handler =
          Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Bold)
        italic_handler =
          Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic)

        registry.register("b", bold_handler)
        registry.register("i", italic_handler)

        # Open bold tag
        open_token =
          Markbridge::Parsers::BBCode::TagStartToken.new(tag: "b", attrs: {}, pos: 0, source: "[b]")
        bold_handler.on_open(token: open_token, context:, registry:)

        bold_element = context.current
        expect(bold_element).to be_a(Markbridge::AST::Bold)

        # Try to close with italic (mismatched)
        close_token =
          Markbridge::Parsers::BBCode::TagEndToken.new(tag: "i", pos: 10, source: "[/i]")
        italic_handler.on_close(token: close_token, context:, registry:)

        # Should still be in bold element
        expect(context.current).to eq(bold_element)

        # Should have added text child with the mismatched tag
        expect(bold_element.children.size).to eq(1)
        expect(bold_element.children.first).to be_a(Markbridge::AST::Text)
        expect(bold_element.children.first.text).to eq("[/i]")
      end

      it "handles complex nesting mismatch with auto-close" do
        # Setup handlers
        bold_handler =
          Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(
            Markbridge::AST::Bold,
            auto_closeable: true,
          )
        italic_handler =
          Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(
            Markbridge::AST::Italic,
            auto_closeable: true,
          )

        registry.register("b", bold_handler)
        registry.register("i", italic_handler)

        # Open [b][i]
        bold_token =
          Markbridge::Parsers::BBCode::TagStartToken.new(tag: "b", attrs: {}, pos: 0, source: "[b]")
        bold_handler.on_open(token: bold_token, context:, registry:)
        bold_element = context.current

        italic_token =
          Markbridge::Parsers::BBCode::TagStartToken.new(tag: "i", attrs: {}, pos: 3, source: "[i]")
        italic_handler.on_open(token: italic_token, context:, registry:)
        italic_element = context.current

        # Try to close bold while in italic (wrong order: [b][i][/b])
        close_bold = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 10, source: "[/b]")
        bold_handler.on_close(token: close_bold, context:, registry:)

        # With auto-close, italic should be auto-closed and bold should be closed
        # Current should now be back at the document root
        expect(context.current).to eq(document)
        # Bold should contain the italic element
        expect(bold_element.children.size).to eq(1)
        expect(bold_element.children.first).to eq(italic_element)
      end
    end
  end

  describe "subclass override examples" do
    it "allows subclasses to override on_open" do
      custom_handler =
        Class.new(described_class) do
          def on_open(token:, context:, registry:, tokens: nil)
            element = Markbridge::AST::Bold.new
            context.push(element)
          end
        end

      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "custom",
          attrs: {
          },
          pos: 0,
          source: "[custom]",
        )

      custom_handler.new.on_open(token:, context:, registry:)

      expect(context.current).to be_a(Markbridge::AST::Bold)
    end

    it "allows subclasses to call super in on_close for custom pre-close behavior" do
      # Example: ListHandler that auto-closes list items before closing the list
      custom_handler_class =
        Class.new(described_class) do
          attr_reader :element_class

          def initialize
            @element_class = Markbridge::AST::List
            super()
          end

          def on_open(token:, context:, registry:, tokens: nil)
            element = Markbridge::AST::List.new(ordered: false)
            context.push(element)
          end

          def on_close(token:, context:, registry:, tokens: nil)
            # Auto-close open list item before closing list
            context.pop if context.current.is_a?(Markbridge::AST::ListItem)
            # Then use default closing behavior
            super
          end
        end

      custom_handler = custom_handler_class.new
      registry.register("list", custom_handler)

      # Open list
      open_list =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "list",
          attrs: {
          },
          pos: 0,
          source: "[list]",
        )
      custom_handler.on_open(token: open_list, context:, registry:)
      list = context.current

      # Open list item manually
      list_item = Markbridge::AST::ListItem.new
      context.push(list_item)

      # Close list (should auto-close list item first)
      close_list =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "list", pos: 20, source: "[/list]")
      custom_handler.on_close(token: close_list, context:, registry:)

      # Should have closed both list item and list
      expect(context.current).to eq(document)
      expect(list.children).to eq([list_item])
    end
  end

  describe "extension contract examples" do
    it "works correctly with multiple nested elements" do
      # Setup handlers
      bold_handler = Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Bold)
      italic_handler =
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic)

      registry.register("b", bold_handler)
      registry.register("i", italic_handler)

      # Simulate: [b][i]text[/i][/b]

      # Open [b]
      bold_handler.on_open(
        token:
          Markbridge::Parsers::BBCode::TagStartToken.new(
            tag: "b",
            attrs: {
            },
            pos: 0,
            source: "[b]",
          ),
        context:,
        registry:,
      )
      bold_element = context.current

      # Open [i]
      italic_handler.on_open(
        token:
          Markbridge::Parsers::BBCode::TagStartToken.new(
            tag: "i",
            attrs: {
            },
            pos: 3,
            source: "[i]",
          ),
        context:,
        registry:,
      )
      italic_element = context.current

      # Add text
      context.add_child(Markbridge::AST::Text.new("text"))

      # Close [/i]
      italic_handler.on_close(
        token: Markbridge::Parsers::BBCode::TagEndToken.new(tag: "i", pos: 10, source: "[/i]"),
        context:,
        registry:,
      )
      expect(context.current).to eq(bold_element)

      # Close [/b]
      bold_handler.on_close(
        token: Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 14, source: "[/b]"),
        context:,
        registry:,
      )
      expect(context.current).to eq(document)

      # Verify structure
      expect(document.children).to eq([bold_element])
      expect(bold_element.children).to eq([italic_element])
      expect(italic_element.children.size).to eq(1)
      expect(italic_element.children.first.text).to eq("text")
    end
  end
end
