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
      end
    end
  end
end
