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

  describe "#try_auto_close" do
    let(:bold_handler) { registry["b"] }
    let(:italic_handler) { registry["i"] }

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
