# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::ClosingStrategies::Reordering do
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.default }
  let(:reconciler) { Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry:) }
  let(:root) { Markbridge::AST::Document.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(root) }
  let(:strategy) { described_class.new(reconciler) }

  context "when exact match" do
    it "pops the element" do
      context.push(Markbridge::AST::Bold.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      scanner = Markbridge::Parsers::BBCode::Scanner.new("")
      tokens = Markbridge::Parsers::BBCode::PeekableEnumerator.new(scanner)

      strategy.handle_close(token:, context:, registry:, tokens:)

      expect(context.current).to eq(root)
    end
  end

  context "when reordering is possible" do
    it "triggers reordering and consumes the matched closing token" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      # Stack: [root, bold, italic], closing bold (depth 1)
      # Tokens: [/i] is coming
      scanner = Markbridge::Parsers::BBCode::Scanner.new("[/i]")
      tokens = Markbridge::Parsers::BBCode::PeekableEnumerator.new(scanner)

      strategy.handle_close(token:, context:, registry:, tokens:)

      expect(context.current).to eq(root)
      expect(context.auto_closed_count).to eq(2)
      # Reordering must consume the upcoming [/i] (auto-close fallback would not)
      expect(tokens.peek).to be_nil
      # Reordering must short-circuit; otherwise super re-runs and appends [/b] as text
      expect(root.children).to contain_exactly(an_instance_of(Markbridge::AST::Bold))
    end
  end

  context "when tokens is nil" do
    it "falls back to auto-close" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      strategy.handle_close(token:, context:, registry:, tokens: nil)

      # Should fall back to auto-close
      expect(context.current).to eq(root)
      expect(context.auto_closed_count).to eq(2)
    end

    it "treats an omitted tokens kwarg the same as tokens: nil" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      strategy.handle_close(token:, context:, registry:)

      expect(context.current).to eq(root)
      expect(context.auto_closed_count).to eq(2)
    end
  end

  context "when closing tags are not adjacent but content follows" do
    it "reopens intervening tags so content stays in the same context" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      # Text follows [/b], so reorder fails and reopen should kick in
      scanner = Markbridge::Parsers::BBCode::Scanner.new(" more[/i]")
      tokens = Markbridge::Parsers::BBCode::PeekableEnumerator.new(scanner)

      strategy.handle_close(token:, context:, registry:, tokens:)

      expect(context.current).to be_a(Markbridge::AST::Italic)
      expect(context.auto_closed_count).to eq(2)
      expect(root.children.map(&:class)).to eq([Markbridge::AST::Bold, Markbridge::AST::Italic])
      # Reopen returning early prevents super from appending the [/b] source as text into the
      # reopened Italic.
      expect(context.current.children).to be_empty
    end
  end

  context "when reordering not possible but auto-close succeeds" do
    it "auto-closes" do
      context.push(Markbridge::AST::Bold.new)
      context.push(Markbridge::AST::Italic.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      # Wrong token coming, so reordering won't work
      scanner = Markbridge::Parsers::BBCode::Scanner.new("[/u]")
      tokens = Markbridge::Parsers::BBCode::PeekableEnumerator.new(scanner)

      strategy.handle_close(token:, context:, registry:, tokens:)

      expect(context.current).to eq(root)
      expect(context.auto_closed_count).to eq(2)
    end
  end

  context "when both reordering and auto-close fail" do
    it "adds closing tag as text" do
      context.push(Markbridge::AST::Bold.new)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "i", pos: 0, source: "[/i]")

      scanner = Markbridge::Parsers::BBCode::Scanner.new("")
      tokens = Markbridge::Parsers::BBCode::PeekableEnumerator.new(scanner)

      strategy.handle_close(token:, context:, registry:, tokens:)

      expect(context.current).to be_a(Markbridge::AST::Bold)
      expect(context.current.children.first.text).to eq("[/i]")
    end
  end

  context "when current is Document (which IS an Element)" do
    it "adds closing tag as text since Document has no handler" do
      # Document inherits from Element, so is_a?(Element) is true
      # But Document has no registered handler, so the closing tag becomes text
      expect(context.current).to eq(root)
      expect(root).to be_a(Markbridge::AST::Element)

      token = Markbridge::Parsers::BBCode::TagEndToken.new(tag: "b", pos: 0, source: "[/b]")

      scanner = Markbridge::Parsers::BBCode::Scanner.new("")
      tokens = Markbridge::Parsers::BBCode::PeekableEnumerator.new(scanner)

      strategy.handle_close(token:, context:, registry:, tokens:)

      expect(context.current).to eq(root)
      # Document IS an Element, so strategy doesn't return early
      # But there's no handler for Document, so [/b] becomes text
      expect(root.children.size).to eq(1)
      expect(root.children.first.text).to eq("[/b]")
    end
  end
end
