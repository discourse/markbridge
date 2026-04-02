# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::Img2Handler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

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

  def make_scanner(tokens)
    Markbridge::Parsers::BBCode::PeekableEnumerator.new(MockScanner.new(tokens))
  end

  def text_token(text, pos: 0)
    Markbridge::Parsers::BBCode::TextToken.new(text:, pos:)
  end

  def start_token(tag: "img2", attrs: {}, source: "[IMG2]", pos: 0)
    Markbridge::Parsers::BBCode::TagStartToken.new(tag:, attrs:, pos:, source:)
  end

  def end_token(tag: "img2", source: "[/IMG2]", pos: 0)
    Markbridge::Parsers::BBCode::TagEndToken.new(tag:, pos:, source:)
  end

  describe "#on_open" do
    it "extracts src from JSON body with HTTP URL" do
      token = start_token(attrs: { option: "JSON" }, source: "[IMG2=JSON]")
      json = '{"data-align":"none","data-size":"full","src":"http://example.com/image.png"}'
      scanner = make_scanner([text_token(json), end_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image = document.children.first
      expect(image).to be_a(Markbridge::AST::Image)
      expect(image.src).to eq("http://example.com/image.png")
    end

    it "extracts src from JSON body with HTTPS URL" do
      token = start_token(attrs: { option: "JSON" }, source: "[IMG2=JSON]")
      json = '{"data-align":"none","src":"https://forums.example.com/core/image.jpg"}'
      scanner = make_scanner([text_token(json), end_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image = document.children.first
      expect(image).to be_a(Markbridge::AST::Image)
      expect(image.src).to eq("https://forums.example.com/core/image.jpg")
    end

    it "produces nothing when JSON body has no src field" do
      token = start_token(attrs: { option: "JSON" }, source: "[IMG2=JSON]")
      json = '{"data-align":"none","data-size":"full"}'
      scanner = make_scanner([text_token(json), end_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      expect(document.children).to be_empty
    end

    it "produces nothing when JSON src is empty" do
      token = start_token(attrs: { option: "JSON" }, source: "[IMG2=JSON]")
      json = '{"src":""}'
      scanner = make_scanner([text_token(json), end_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      expect(document.children).to be_empty
    end

    it "handles bare [IMG2]url[/IMG2] without JSON option" do
      token = start_token(attrs: {}, source: "[IMG2]")
      scanner = make_scanner([text_token("https://example.com/photo.jpg"), end_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image = document.children.first
      expect(image).to be_a(Markbridge::AST::Image)
      expect(image.src).to eq("https://example.com/photo.jpg")
    end

    it "handles case-insensitive JSON option" do
      token = start_token(attrs: { option: "json" }, source: "[IMG2=json]")
      json = '{"src":"http://example.com/img.png"}'
      scanner = make_scanner([text_token(json), end_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image = document.children.first
      expect(image).to be_a(Markbridge::AST::Image)
      expect(image.src).to eq("http://example.com/img.png")
    end

    it "produces nothing when there is no closing tag" do
      token = start_token(attrs: { option: "JSON" }, source: "[IMG2=JSON]")
      scanner = make_scanner([text_token("some content")])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      expect(document.children).to be_empty
    end

    it "handles JSON with escaped slashes in src" do
      token = start_token(attrs: { option: "JSON" }, source: "[IMG2=JSON]")
      json = '{"src":"http:\/\/example.com\/path\/image.png"}'
      scanner = make_scanner([text_token(json), end_token])

      handler.on_open(token:, context:, registry:, tokens: scanner)

      image = document.children.first
      expect(image).to be_a(Markbridge::AST::Image)
      expect(image.src).to eq("http:\\/\\/example.com\\/path\\/image.png")
    end
  end

  describe "#on_close" do
    it "emits orphaned close tag as text" do
      token = end_token(source: "[/IMG2]")

      handler.on_close(token:, context:, registry:)

      text = document.children.first
      expect(text).to be_a(Markbridge::AST::Text)
      expect(text.text).to eq("[/IMG2]")
    end
  end

  describe "end-to-end via Markbridge.bbcode_to_markdown" do
    it "converts [IMG2=JSON] with HTTP src to image markdown" do
      input =
        '[IMG2=JSON]{"data-align":"none","data-size":"full","src":"http://example.com/image.png"}[/IMG2]'
      result = Markbridge.bbcode_to_markdown(input)
      expect(result).to eq("![](http://example.com/image.png)")
    end

    it "converts bare [IMG2] to image markdown" do
      input = "[IMG2]http://example.com/photo.jpg[/IMG2]"
      result = Markbridge.bbcode_to_markdown(input)
      expect(result).to eq("![](http://example.com/photo.jpg)")
    end

    it "strips [IMG2=JSON] with no src" do
      input = 'Hello [IMG2=JSON]{"data-align":"none"}[/IMG2] world'
      result = Markbridge.bbcode_to_markdown(input)
      expect(result).to eq("Hello  world")
    end

    it "converts [IMG2=JSON] inline with surrounding text" do
      input = 'Before [IMG2=JSON]{"src":"http://example.com/img.png"}[/IMG2] after'
      result = Markbridge.bbcode_to_markdown(input)
      expect(result).to eq("Before ![](http://example.com/img.png) after")
    end
  end
end
