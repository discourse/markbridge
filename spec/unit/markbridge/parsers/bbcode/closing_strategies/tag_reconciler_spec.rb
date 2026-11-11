# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler do
  subject(:reconciler) { described_class.new(registry:) }

  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:root) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(root) }

  def tokens_for(input)
    scanner = Markbridge::Parsers::BBCode::Scanner.new(input)
    Markbridge::Parsers::BBCode::PeekableEnumerator.new(scanner)
  end

  describe "#close_inside_block" do
    let(:quote) { Markbridge::AST::Quote.new }

    it "ends what is open inside the block and leaves the block open" do
      context.push(quote)
      context.push(Markbridge::AST::List.new)
      context.push(Markbridge::AST::ListItem.new)
      context.push(Markbridge::AST::Bold.new)

      reconciler.close_inside_block(handler: registry["quote"], context:)

      expect(context.current).to eq(quote)
    end

    it "expects the closing tags of what it ends, and not the one of the block" do
      context.push(quote)
      context.push(Markbridge::AST::List.new)
      context.push(Markbridge::AST::ListItem.new)

      reconciler.close_inside_block(handler: registry["quote"], context:)

      expect(context.closing_tag_due?(registry["list"])).to be true
      expect(context.closing_tag_due?(registry["*"])).to be true
      expect(context.closing_tag_due?(registry["quote"])).to be false
    end

    it "counts what it ends, without the items, rows and cells" do
      context.push(quote)
      context.push(Markbridge::AST::Table.new)
      context.push(Markbridge::AST::TableRow.new)
      context.push(Markbridge::AST::TableCell.new)
      context.push(Markbridge::AST::List.new)
      context.push(Markbridge::AST::ListItem.new)
      context.push(Markbridge::AST::Bold.new)

      reconciler.close_inside_block(handler: registry["quote"], context:)

      expect(context.auto_closed_count).to eq(3)
    end

    {
      "quote" => Markbridge::AST::Quote.new,
      "spoiler" => Markbridge::AST::Spoiler.new,
      "center" => Markbridge::AST::Align.new(alignment: "center"),
      "list" => Markbridge::AST::List.new,
      "table" => Markbridge::AST::Table.new,
      "tr" => Markbridge::AST::TableRow.new,
      "td" => Markbridge::AST::TableCell.new,
    }.each do |tag, block|
      it "ends bold that is open in a #{tag}" do
        context.push(block)
        context.push(Markbridge::AST::Bold.new)

        reconciler.close_inside_block(handler: registry[tag], context:)

        expect(context.current).to eq(block)
        expect(context.auto_closed_count).to eq(1)
      end
    end

    it "ends up to the innermost block of that kind" do
      inner = Markbridge::AST::Quote.new
      context.push(quote)
      context.push(inner)
      context.push(Markbridge::AST::List.new)

      reconciler.close_inside_block(handler: registry["quote"], context:)

      expect(context.current).to eq(inner)
    end

    it "does nothing for the closing tag of an inline element" do
      context.push(Markbridge::AST::Bold.new)
      context.push(quote)

      reconciler.close_inside_block(handler: registry["b"], context:)

      expect(context.current).to eq(quote)
      expect(context.auto_closed_count).to eq(0)
    end

    it "does nothing when the block is not open" do
      context.push(Markbridge::AST::List.new)

      reconciler.close_inside_block(handler: registry["quote"], context:)

      expect(context.current).to be_a(Markbridge::AST::List)
      expect(context.auto_closed_count).to eq(0)
    end

    it "does nothing when the block is the current element" do
      context.push(quote)

      reconciler.close_inside_block(handler: registry["quote"], context:)

      expect(context.current).to eq(quote)
      expect(context.auto_closed_count).to eq(0)
    end
  end

  describe "#close_item_without_list" do
    let(:quote) { Markbridge::AST::Quote.new }
    let(:item) { Markbridge::AST::ListItem.new }

    it "ends the item, with what is open in it, for an element around it" do
      context.push(quote)
      context.push(item)
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      reconciler.close_item_without_list(handler: registry["quote"], context:)

      expect(context.current).to eq(quote)
      expect(context.auto_closed_count).to eq(2)
    end

    it "ends the item for an element further out" do
      context.push(quote)
      context.push(Markbridge::AST::Bold.new)
      context.push(item)

      reconciler.close_item_without_list(handler: registry["quote"], context:)

      expect(context.current).to be_a(Markbridge::AST::Bold)
      expect(context.auto_closed_count).to eq(0)
    end

    it "leaves the item open for an element inside of it" do
      context.push(quote)
      context.push(item)
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      reconciler.close_item_without_list(handler: registry["b"], context:)

      expect(context.current).to be_a(Markbridge::AST::Italic)
    end

    it "leaves the item open for a tag that nothing around it opened" do
      context.push(item)

      reconciler.close_item_without_list(handler: registry["quote"], context:)

      expect(context.current).to eq(item)
    end

    it "leaves an item in a list open" do
      context.push(quote)
      context.push(Markbridge::AST::List.new)
      context.push(item)

      reconciler.close_item_without_list(handler: registry["quote"], context:)

      expect(context.current).to eq(item)
    end

    it "looks at the innermost item only" do
      context.push(quote)
      context.push(Markbridge::AST::ListItem.new)
      context.push(Markbridge::AST::List.new)
      context.push(item)

      reconciler.close_item_without_list(handler: registry["quote"], context:)

      expect(context.current).to eq(item)
    end

    it "does nothing without an item" do
      context.push(quote)
      context.push(Markbridge::AST::Bold.new)

      reconciler.close_item_without_list(handler: registry["quote"], context:)

      expect(context.current).to be_a(Markbridge::AST::Bold)
      expect(context.auto_closed_count).to eq(0)
    end
  end

  describe "#try_auto_close" do
    let(:bold_handler) { registry["b"] }
    let(:italic_handler) { registry["i"] }

    it "closes a target that is not auto-closeable, with what is open in it" do
      context.push(Markbridge::AST::Quote.new)
      context.push(Markbridge::AST::Bold.new)

      result = reconciler.try_auto_close(handler: registry["quote"], context:)

      expect(result).to be true
      expect(context.current).to eq(root)
      expect(context.auto_closed_count).to eq(2)
    end

    it "closes the current element when its handler matches the closing handler" do
      context.push(Markbridge::AST::Bold.new)

      result = reconciler.try_auto_close(handler: bold_handler, context:)

      expect(result).to be true
      expect(context.current).to eq(root)
      expect(context.auto_closed_count).to eq(1)
    end

    it "auto-closes intervening elements when the match is deeper in the stack" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)
      context.push(Markbridge::AST::Underline.new)

      result = reconciler.try_auto_close(handler: bold_handler, context:)

      expect(result).to be true
      expect(context.current).to eq(root)
      expect(context.auto_closed_count).to eq(3)
    end

    it "returns false when no element on the stack matches" do
      context.push(Markbridge::AST::Bold.new)

      result = reconciler.try_auto_close(handler: italic_handler, context:)

      expect(result).to be false
      expect(context.current).to be_a(Markbridge::AST::Bold)
      expect(context.auto_closed_count).to eq(0)
    end

    it "returns false when the matching element is at MAX_AUTO_CLOSE_DEPTH or deeper" do
      context.push(Markbridge::AST::Bold.new)
      described_class::MAX_AUTO_CLOSE_DEPTH.times { context.push(Markbridge::AST::Italic.new) }

      result = reconciler.try_auto_close(handler: bold_handler, context:)

      expect(result).to be false
      expect(context.auto_closed_count).to eq(0)
    end

    it "succeeds when the matching element is at exactly MAX_AUTO_CLOSE_DEPTH - 1 (still in window)" do
      context.push(Markbridge::AST::Bold.new)
      (described_class::MAX_AUTO_CLOSE_DEPTH - 1).times do
        context.push(Markbridge::AST::Italic.new)
      end

      result = reconciler.try_auto_close(handler: bold_handler, context:)

      expect(result).to be true
      expect(context.current).to be_a(Markbridge::AST::Document)
    end

    it "returns false when an intervening element is not auto-closeable" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::List.new)
      context.push(Markbridge::AST::Italic.new)

      result = reconciler.try_auto_close(handler: bold_handler, context:)

      expect(result).to be false
      expect(context.current).to be_a(Markbridge::AST::Italic)
      expect(context.auto_closed_count).to eq(0)
    end

    it "does not modify state when returning false" do
      context.push(Markbridge::AST::Italic.new)
      original_current = context.current

      result = reconciler.try_auto_close(handler: bold_handler, context:)

      expect(result).to be false
      expect(context.current).to eq(original_current)
    end
  end

  describe "#try_reopen" do
    let(:bold_handler) { registry["b"] }
    let(:italic_handler) { registry["i"] }

    it "returns false when the element right inside the target is not auto-closeable" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::List.new)
      context.push(Markbridge::AST::Italic.new)
      context.push(Markbridge::AST::Underline.new)

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens: tokens_for("text"))

      expect(result).to be false
      expect(context.current).to be_a(Markbridge::AST::Underline)
    end

    it "reopens a color with its color and a link with its address" do
      color = Markbridge::AST::Color.new(color: "red")
      link = Markbridge::AST::Url.new(href: "https://example.com")
      color << Markbridge::AST::Text.new("x")
      context.push(Markbridge::AST::Bold.new)
      context.push(color)
      context.push(link)

      reconciler.try_reopen(handler: bold_handler, context:, tokens: tokens_for(" more"))

      reopened_link, reopened_color = context.elements_from_current
      expect(reopened_link).to be_a(Markbridge::AST::Url)
      expect(reopened_link.href).to eq("https://example.com")
      expect(reopened_color).to be_a(Markbridge::AST::Color)
      expect(reopened_color.color).to eq("red")
      expect(reopened_color).not_to equal(color)
      expect(reopened_color.children).to eq([reopened_link])
      expect(color.children.map(&:class)).to eq([Markbridge::AST::Text, Markbridge::AST::Url])
    end

    it "closes a target that is not auto-closeable and reopens what was open in it" do
      context.push(Markbridge::AST::Quote.new)
      context.push(Markbridge::AST::Bold.new)

      result =
        reconciler.try_reopen(handler: registry["quote"], context:, tokens: tokens_for(" more"))

      expect(result).to be true
      expect(context.elements_from_current.map(&:class)).to eq(
        [Markbridge::AST::Bold, Markbridge::AST::Document],
      )
    end

    it "closes target and reopens intervening tags when content follows" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)
      context.push(Markbridge::AST::Underline.new)

      tokens = tokens_for(" more text")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be true
      expect(context.auto_closed_count).to eq(3)
      expect(context.current).to be_a(Markbridge::AST::Underline)
      expect(context.elements_from_current.map(&:class)).to eq(
        [Markbridge::AST::Underline, Markbridge::AST::Italic, Markbridge::AST::Document],
      )
    end

    it "reopens every intervening tag, not just the immediately innermost" do
      # 3 levels of intervening tags before the target
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)
      context.push(Markbridge::AST::Underline.new)
      context.push(Markbridge::AST::Strikethrough.new)

      tokens = tokens_for(" more text")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be true
      # Stack from current: [strikethrough, underline, italic, document]
      expect(context.elements_from_current.map(&:class)).to eq(
        [
          Markbridge::AST::Strikethrough,
          Markbridge::AST::Underline,
          Markbridge::AST::Italic,
          Markbridge::AST::Document,
        ],
      )
    end

    it "reopens when next token is an opening tag" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      tokens = tokens_for("[u]x[/u]")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be true
      expect(context.current).to be_a(Markbridge::AST::Italic)
    end

    it "returns false when the next token is a closing tag (plain auto-close is correct)" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      tokens = tokens_for("[/i]")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be false
      expect(context.auto_closed_count).to eq(0)
    end

    it "returns false when there are no more tokens" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      tokens = tokens_for("")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be false
      expect(context.auto_closed_count).to eq(0)
    end

    it "returns false when the target isn't on the stack" do
      context.push(Markbridge::AST::Italic.new)

      tokens = tokens_for("text")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be false
    end

    it "returns false when the target is beyond MAX_AUTO_CLOSE_DEPTH on the stack" do
      context.push(Markbridge::AST::Bold.new)
      described_class::MAX_AUTO_CLOSE_DEPTH.times { context.push(Markbridge::AST::Italic.new) }

      tokens = tokens_for("text")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be false
    end

    it "succeeds when the target is at exactly MAX_AUTO_CLOSE_DEPTH - 1 (still in window)" do
      context.push(Markbridge::AST::Bold.new)
      (described_class::MAX_AUTO_CLOSE_DEPTH - 1).times do
        context.push(Markbridge::AST::Italic.new)
      end

      tokens = tokens_for("text")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be true
    end

    it "returns false when current matches the target (nothing to reopen)" do
      context.push(Markbridge::AST::Bold.new)

      tokens = tokens_for("text")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be false
      expect(context.auto_closed_count).to eq(0)
    end

    it "returns false when an intervening element is not auto-closeable" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::List.new(ordered: false))
      context.push(Markbridge::AST::Italic.new)

      tokens = tokens_for("text")

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens:)

      expect(result).to be false
      expect(context.auto_closed_count).to eq(0)
    end

    it "returns false when tokens is nil" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      result = reconciler.try_reopen(handler: bold_handler, context:, tokens: nil)

      expect(result).to be false
    end
  end

  describe "#try_reorder" do
    let(:bold_handler) { registry["b"] }
    let(:italic_handler) { registry["i"] }
    let(:underline_handler) { registry["u"] }
    let(:strikethrough_handler) { registry["s"] }

    context "when reordering can close only current element" do
      it "returns true and closes current element" do
        context.push(Markbridge::AST::Bold.new)
        context.push(Markbridge::AST::Italic.new)

        tokens = tokens_for("[/b]")

        result = reconciler.try_reorder(handler: italic_handler, tokens:, context:)

        expect(result).to be true
        expect(context.current).to be_a(Markbridge::AST::Bold)
        expect(context.auto_closed_count).to eq(1)
      end
    end

    context "when reordering needs to close current and target" do
      it "returns true and closes both handlers" do
        context.push(Markbridge::AST::Bold.new)
        context.push(Markbridge::AST::Italic.new)

        tokens = tokens_for("[/i]")

        result = reconciler.try_reorder(handler: bold_handler, tokens:, context:)

        expect(result).to be true
        expect(context.current).to eq(root)
        expect(context.auto_closed_count).to eq(2)
        # The trailing [/i] must be consumed so the parser doesn't re-process it.
        expect(tokens.peek).to be_nil
      end
    end

    context "when target is not found" do
      it "returns false" do
        context.push(Markbridge::AST::Bold.new)

        tokens = tokens_for("")

        result = reconciler.try_reorder(handler: italic_handler, tokens:, context:)

        expect(result).to be false
      end
    end

    context "when depth exceeds MAX_AUTO_CLOSE_DEPTH" do
      it "returns false" do
        described_class::MAX_AUTO_CLOSE_DEPTH.times { context.push(Markbridge::AST::Italic.new) }

        tokens = tokens_for("[/i]")

        result = reconciler.try_reorder(handler: bold_handler, tokens:, context:)

        expect(result).to be false
      end
    end

    context "when non-auto-closeable element blocks reordering" do
      it "returns false" do
        context.push(Markbridge::AST::Bold.new)
        context.push(Markbridge::AST::List.new(ordered: false))
        context.push(Markbridge::AST::Italic.new)

        tokens = tokens_for("[/i]")

        result = reconciler.try_reorder(handler: bold_handler, tokens:, context:)

        expect(result).to be false
      end
    end

    context "when closing handlers don't match opening handlers" do
      it "returns false when peeked closing tag is wrong handler" do
        context.push(Markbridge::AST::Bold.new)
        context.push(Markbridge::AST::Italic.new)

        tokens = tokens_for("[/s]")

        result = reconciler.try_reorder(handler: bold_handler, tokens:, context:)

        expect(result).to be false
      end
    end

    context "when not enough closing tags are available" do
      it "returns false" do
        context.push(Markbridge::AST::Bold.new)
        context.push(Markbridge::AST::Italic.new)
        context.push(Markbridge::AST::Underline.new)

        tokens = tokens_for("text")

        result = reconciler.try_reorder(handler: bold_handler, tokens:, context:)

        expect(result).to be false
      end
    end

    context "when peeked token is not TagEndToken" do
      it "returns false when no closing tags are available" do
        context.push(Markbridge::AST::Bold.new)
        context.push(Markbridge::AST::Italic.new)

        tokens = tokens_for("text")

        result = reconciler.try_reorder(handler: bold_handler, tokens:, context:)

        expect(result).to be false
        expect(context.current).to be_a(Markbridge::AST::Italic)
        expect(context.auto_closed_count).to eq(0)
      end
    end

    context "with three nested tags and matching closing sequence" do
      it "consumes intermediate closing tags and closes all three" do
        context.push(Markbridge::AST::Bold.new)
        context.push(Markbridge::AST::Italic.new)
        context.push(Markbridge::AST::Underline.new)

        tokens = tokens_for("[/u][/i]")

        result = reconciler.try_reorder(handler: bold_handler, tokens:, context:)

        expect(result).to be true
        expect(context.current).to eq(root)
        expect(context.auto_closed_count).to eq(3)
        # All matched closing tokens must be consumed.
        expect(tokens.peek).to be_nil
      end

      it "leaves extra closing tags after the matched sequence in the token stream" do
        # Bold contains italic. Reordering should consume the [/i] paired with
        # italic but leave the trailing [/u] alone for the parser to handle.
        context.push(Markbridge::AST::Bold.new)
        context.push(Markbridge::AST::Italic.new)

        tokens = tokens_for("[/i][/u]")

        reconciler.try_reorder(handler: bold_handler, tokens:, context:)

        expect(tokens.peek).to be_a(Markbridge::Parsers::BBCode::TagEndToken)
        expect(tokens.peek.tag).to eq("u")
      end
    end
  end
end
