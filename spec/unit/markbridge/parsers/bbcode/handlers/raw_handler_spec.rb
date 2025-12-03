# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::RawHandler do
  let(:element_class) { Markbridge::AST::Code }
  let(:handler) { described_class.new(element_class) }

  describe "#initialize" do
    it "accepts an element class" do
      expect { described_class.new(Markbridge::AST::Code) }.not_to raise_error
    end

    it "accepts a custom collector" do
      custom_collector = Markbridge::Parsers::BBCode::RawContentCollector.new
      handler = described_class.new(element_class, collector: custom_collector)
      expect(handler).to be_a(described_class)
    end
  end

  describe "#on_open" do
    let(:document) { Markbridge::AST::Document.new }
    let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.new }
    let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

    # Simple scanner mock that implements the next_token interface
    # This is NOT a spy or verified double - it's a simple test double
    class MockScanner
      def initialize(tokens)
        @tokens = tokens
        @index = 0
      end

      def next_token
        return nil if @index >= @tokens.length

        token = @tokens[@index]
        @index += 1
        token
      end
    end

    it "creates element with collected content from simple code block" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "code",
          attrs: {
            option: "ruby",
          },
          pos: 0,
          source: "[code=ruby]",
        )
      text_token = Markbridge::Parsers::BBCode::TextToken.new(text: "puts 'hello'", pos: 11)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "code", pos: 23, source: "[/code]")
      scanner = MockScanner.new([text_token, close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      code_element = document.children.first
      expect(code_element).to be_a(Markbridge::AST::Code)
      expect(code_element.language).to eq("ruby")
      expect(code_element.children.size).to eq(1)
      expect(code_element.children.first).to be_a(Markbridge::AST::Text)
      expect(code_element.children.first.text).to eq("puts 'hello'")
    end

    it "creates element without text child when content is empty" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "code",
          attrs: {
          },
          pos: 0,
          source: "[code]",
        )
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "code", pos: 6, source: "[/code]")
      scanner = MockScanner.new([close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      code_element = document.children.first
      expect(code_element).to be_a(Markbridge::AST::Code)
      expect(code_element.children).to be_empty
    end

    it "extracts language from :lang attribute" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "code",
          attrs: {
            lang: "python",
          },
          pos: 0,
          source: "[code lang=python]",
        )
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "code", pos: 18, source: "[/code]")
      scanner = MockScanner.new([close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      code_element = document.children.first
      expect(code_element).to be_a(Markbridge::AST::Code)
      expect(code_element.language).to eq("python")
    end

    it "extracts language from :option attribute" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "code",
          attrs: {
            option: "javascript",
          },
          pos: 0,
          source: "[code=javascript]",
        )
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "code", pos: 17, source: "[/code]")
      scanner = MockScanner.new([close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      code_element = document.children.first
      expect(code_element.language).to eq("javascript")
    end

    it "handles nested tags in raw content" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "code",
          attrs: {
          },
          pos: 0,
          source: "[code]",
        )
      text_token = Markbridge::Parsers::BBCode::TextToken.new(text: "[b]not bold[/b]", pos: 6)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "code", pos: 21, source: "[/code]")
      scanner = MockScanner.new([text_token, close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      code_element = document.children.first
      expect(code_element.children.first.text).to eq("[b]not bold[/b]")
    end

    it "handles nested code blocks correctly" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "code",
          attrs: {
          },
          pos: 0,
          source: "[code]",
        )
      nested_open =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "code",
          attrs: {
          },
          pos: 6,
          source: "[code]",
        )
      text_token = Markbridge::Parsers::BBCode::TextToken.new(text: "nested", pos: 12)
      nested_close =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "code", pos: 18, source: "[/code]")
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "code", pos: 25, source: "[/code]")
      scanner = MockScanner.new([nested_open, text_token, nested_close, close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      code_element = document.children.first
      # Should collect everything until the matching closing tag
      expect(code_element.children.first.text).to eq("[code]nested[/code]")
    end
  end
end
