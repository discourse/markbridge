# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::AttachmentHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  # Simple scanner double
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
    it "parses phpBB-style index with filename" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "attachment",
          attrs: {
            option: "0",
          },
          pos: 0,
          source: "[attachment=0]",
        )
      text_token = Markbridge::Parsers::BBCode::TextToken.new(text: "image.jpg", pos: 14)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(
          tag: "attachment",
          pos: 23,
          source: "[/attachment]",
        )
      scanner =
        Markbridge::Parsers::BBCode::PeekableEnumerator.new(
          MockScanner.new([text_token, close_token]),
        )

      handler.on_open(token:, context:, registry:, tokens: scanner)

      attachment = document.children.first
      expect(attachment).to be_a(Markbridge::AST::Attachment)
      expect(attachment.id).to be_nil
      expect(attachment.index).to eq("0")
      expect(attachment.filename).to eq("image.jpg")
    end

    it "parses vBulletin-style id from option content" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "attach",
          attrs: {
            option: "CONFIG",
          },
          pos: 0,
          source: "[ATTACH=CONFIG]",
        )
      text_token = Markbridge::Parsers::BBCode::TextToken.new(text: "1234", pos: 14)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "attach", pos: 18, source: "[/ATTACH]")
      scanner =
        Markbridge::Parsers::BBCode::PeekableEnumerator.new(
          MockScanner.new([text_token, close_token]),
        )

      handler.on_open(token:, context:, registry:, tokens: scanner)

      attachment = document.children.first
      expect(attachment.id).to eq("1234")
      expect(attachment.index).to be_nil
    end

    it "parses XenForo-style id with type and alt attributes" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "attach",
          attrs: {
            type: "full",
            alt: "diagram",
          },
          pos: 0,
          source: '[ATTACH type="full" alt="diagram"]',
        )
      text_token = Markbridge::Parsers::BBCode::TextToken.new(text: "5678", pos: 33)
      close_token =
        Markbridge::Parsers::BBCode::TagEndToken.new(tag: "attach", pos: 37, source: "[/ATTACH]")
      scanner =
        Markbridge::Parsers::BBCode::PeekableEnumerator.new(
          MockScanner.new([text_token, close_token]),
        )

      handler.on_open(token:, context:, registry:, tokens: scanner)

      attachment = document.children.first
      expect(attachment.id).to eq("5678")
      expect(attachment.alt).to eq("diagram")
    end

    it "handles attribute-only SMF-style attachments without closing tag" do
      token =
        Markbridge::Parsers::BBCode::TagStartToken.new(
          tag: "attach",
          attrs: {
            id: "2",
            msg: "9876",
          },
          pos: 0,
          source: "[attach id=2 msg=9876]",
        )
      scanner = Markbridge::Parsers::BBCode::PeekableEnumerator.new(MockScanner.new([]))

      handler.on_open(token:, context:, registry:, tokens: scanner)

      attachment = document.children.first
      expect(attachment.id).to eq("9876")
      expect(attachment.index).to eq("2")
      expect(attachment.filename).to be_nil
    end
  end
end
