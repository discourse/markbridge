# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::ImageHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  # Simple scanner mock that implements the next_token interface
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

  describe "#on_open" do
    it "creates Image element with src from content" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "img",
          attrs: {
          },
          pos: 0,
          source: "[img]",
        )
      text_token =
        Markbridge::Parsers::BBCode::TextToken.new(text: "https://example.com/image.png", pos: 5)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "img", pos: 35, source: "[/img]")
      scanner = MockScanner.new([text_token, close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image_element = document.children.first
      expect(image_element).to be_a(Markbridge::AST::Image)
      expect(image_element.src).to eq("https://example.com/image.png")
      expect(image_element.width).to be_nil
      expect(image_element.height).to be_nil
    end

    it "creates Image element with width and height from WIDTHxHEIGHT option" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "img",
          attrs: {
            option: "100x200",
          },
          pos: 0,
          source: "[img=100x200]",
        )
      text_token =
        Markbridge::Parsers::BBCode::TextToken.new(text: "https://example.com/image.png", pos: 13)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "img", pos: 43, source: "[/img]")
      scanner = MockScanner.new([text_token, close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image_element = document.children.first
      expect(image_element).to be_a(Markbridge::AST::Image)
      expect(image_element.src).to eq("https://example.com/image.png")
      expect(image_element.width).to eq(100)
      expect(image_element.height).to eq(200)
    end

    it "creates Image element with width from numeric option" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "img",
          attrs: {
            option: "150",
          },
          pos: 0,
          source: "[img=150]",
        )
      text_token =
        Markbridge::Parsers::BBCode::TextToken.new(text: "https://example.com/image.png", pos: 9)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "img", pos: 39, source: "[/img]")
      scanner = MockScanner.new([text_token, close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image_element = document.children.first
      expect(image_element).to be_a(Markbridge::AST::Image)
      expect(image_element.src).to eq("https://example.com/image.png")
      expect(image_element.width).to eq(150)
      expect(image_element.height).to be_nil
    end

    it "creates Image element with width and height from attributes" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "img",
          attrs: {
            width: "300",
            height: "400",
          },
          pos: 0,
          source: "[img width=300 height=400]",
        )
      text_token =
        Markbridge::Parsers::BBCode::TextToken.new(text: "https://example.com/image.png", pos: 26)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "img", pos: 56, source: "[/img]")
      scanner = MockScanner.new([text_token, close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image_element = document.children.first
      expect(image_element).to be_a(Markbridge::AST::Image)
      expect(image_element.src).to eq("https://example.com/image.png")
      expect(image_element.width).to eq(300)
      expect(image_element.height).to eq(400)
    end

    it "creates Image element with only width from attribute" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "img",
          attrs: {
            width: "250",
          },
          pos: 0,
          source: "[img width=250]",
        )
      text_token =
        Markbridge::Parsers::BBCode::TextToken.new(text: "https://example.com/image.png", pos: 15)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "img", pos: 45, source: "[/img]")
      scanner = MockScanner.new([text_token, close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image_element = document.children.first
      expect(image_element).to be_a(Markbridge::AST::Image)
      expect(image_element.src).to eq("https://example.com/image.png")
      expect(image_element.width).to eq(250)
      expect(image_element.height).to be_nil
    end

    it "creates Image element with empty src when content is empty" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "img",
          attrs: {
          },
          pos: 0,
          source: "[img]",
        )
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "img", pos: 5, source: "[/img]")
      scanner = MockScanner.new([close_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image_element = document.children.first
      expect(image_element).to be_a(Markbridge::AST::Image)
      expect(image_element.src).to eq("")
    end
  end
end
