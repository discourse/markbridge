# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::AttachmentHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  def tag_start(tag: "attachment", attrs: {}, source: nil)
    Markbridge::Parsers::BBCode::TagStartToken.new(
      tag:,
      attrs:,
      pos: 0,
      source: source || "[#{tag}]",
    )
  end

  def tag_end(tag: "attachment")
    Markbridge::Parsers::BBCode::TagEndToken.new(tag:, pos: 0, source: "[/#{tag}]")
  end

  def text_token(text)
    Markbridge::Parsers::BBCode::TextToken.new(text:, pos: 0)
  end

  def tokens_for(*token_list)
    scanner =
      Class
        .new do
          def initialize(tokens)
            @tokens = tokens
            @index = 0
          end

          def next_token
            t = @tokens[@index]
            @index += 1 if t
            t
          end
        end
        .new(token_list)
    Markbridge::Parsers::BBCode::PeekableEnumerator.new(scanner)
  end

  def open_with(attrs: {}, body: nil, tag: "attachment")
    tokens =
      if body.nil?
        tokens_for
      else
        tokens_for(text_token(body), tag_end(tag:))
      end
    handler.on_open(token: tag_start(tag:, attrs:), context:, registry:, tokens:)
    document.children.first
  end

  describe "#initialize" do
    it "exposes AST::Attachment as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Attachment)
    end

    it "uses a default RawContentCollector when none is supplied",
       mutant_expression: %w[
         Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#initialize
         Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#collect_content
       ] do
      expect(open_with(attrs: { option: "0" }, body: "body-content").filename).to eq("body-content")
    end

    it "accepts a custom collector for dependency injection" do
      custom =
        Class
          .new do
            def collect(_tag, _tokens)
              Markbridge::Parsers::BBCode::RawContentResult.new(
                content: "CUSTOM CONTENT",
                closed: true,
              )
            end
          end
          .new
      tokens = tokens_for(tag_end)
      described_class.new(collector: custom).on_open(
        token: tag_start(attrs: { option: "0" }),
        context:,
        registry:,
        tokens:,
      )

      expect(document.children.first.filename).to eq("CUSTOM CONTENT")
    end
  end

  describe "#on_open" do
    context "with phpBB-style index + filename body" do
      it "uses option as index and body as filename" do
        att = open_with(attrs: { option: "0" }, body: "image.jpg")
        expect(att.id).to be_nil
        expect(att.index).to eq("0")
        expect(att.filename).to eq("image.jpg")
      end
    end

    context "with vBulletin-style id from body" do
      it "uses numeric body as id when option is non-numeric",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#numeric?
         ] do
        att = open_with(attrs: { option: "CONFIG" }, body: "1234", tag: "attach")
        expect(att.id).to eq("1234")
        expect(att.index).to be_nil
      end

      it "uses non-numeric body as id when no other anchor is set",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#apply_body_content
         ] do
        att = open_with(body: "image.jpg")
        expect(att.id).to eq("image.jpg")
        expect(att.filename).to be_nil
      end
    end

    context "with XenForo-style id, type, and alt" do
      it "uses body as id and stores alt" do
        att = open_with(attrs: { type: "full", alt: "diagram" }, body: "5678", tag: "attach")
        expect(att.id).to eq("5678")
        expect(att.alt).to eq("diagram")
      end
    end

    context "with SMF-style id+msg attributes (no body)" do
      it "uses msg as id and id-attr as index",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#preferred_id
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#preferred_index
         ] do
        att = open_with(attrs: { id: "2", msg: "9876" }, tag: "attach")
        expect(att.id).to eq("9876")
        expect(att.index).to eq("2")
        expect(att.filename).to be_nil
      end

      it "uses :id directly when :msg is whitespace-only",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#preferred_id
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#presence
         ] do
        att = open_with(attrs: { id: "42", msg: "   " })
        expect(att.id).to eq("42")
      end

      it "leaves index unset when :msg is absent (does not promote :id)",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#preferred_index
         ] do
        att = open_with(attrs: { id: "42" })
        expect(att.id).to eq("42")
        expect(att.index).to be_nil
      end

      it "prefers an explicit :index over the SMF-style :id->index promotion",
         mutant_expression:
           "Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#preferred_index" do
        att = open_with(attrs: { index: "7", id: "2", msg: "99" })
        expect(att.index).to eq("7")
      end

      it "treats whitespace-only :index as absent",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#preferred_index
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#presence
         ] do
        att = open_with(attrs: { index: "   ", id: "2", msg: "99" })
        expect(att.index).to eq("2")
      end

      it "leaves index unset when :msg key exists but is nil after normalization",
         mutant_expression:
           "Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#preferred_index" do
        att = open_with(attrs: { msg: nil, id: "2" })
        expect(att.index).to be_nil
      end
    end

    context "with no tokens available" do
      it "still builds attachment using only the attrs",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#collect_content
         ] do
        handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:, tokens: nil)

        expect(document.children.first.id).to eq("42")
      end

      it "treats an omitted tokens kwarg the same as tokens: nil" do
        handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:)

        expect(document.children.first.id).to eq("42")
      end
    end

    context "with whitespace normalization" do
      it "trims whitespace-only attribute values via presence",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#normalize_attrs
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#presence
         ] do
        att = open_with(attrs: { id: "   ", msg: "9876" })
        expect(att.id).to eq("9876")
        expect(att.index).to be_nil
      end

      it "normalizes whitespace-only :filename and :alt to nil" do
        att = open_with(attrs: { id: "42", filename: "   ", alt: "\t " })
        expect(att.filename).to be_nil
        expect(att.alt).to be_nil
      end

      it "preserves an explicit :filename when id is also set",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#apply_body_content
         ] do
        att = open_with(attrs: { id: "42", filename: "doc.pdf" })
        expect(att.filename).to eq("doc.pdf")
      end

      it "treats whitespace-only body as nil filename",
         mutant_expression: %w[
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#on_open
           Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#presence
         ] do
        att = open_with(attrs: { option: "0" }, body: "   ")
        expect(att.filename).to be_nil
      end
    end
  end

  describe "#numeric? (via #on_open option/body classification)" do
    it "treats option with non-digit char as non-numeric (not promoted to index)" do
      att = open_with(attrs: { option: "12a3" }, body: "image.jpg")
      expect(att.id).to eq("image.jpg")
      expect(att.index).to be_nil
    end

    it "treats option after presence-stripping as numeric (promotes to index)" do
      att = open_with(attrs: { option: " 123" }, body: "img.jpg")
      expect(att.index).to eq("123")
    end

    it "treats nil option without crashing (no body, no option)" do
      handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:, tokens: nil)
      expect(document.children.first.id).to eq("42")
    end

    it "treats numeric body as id when no other anchor is set" do
      att = open_with(body: "1234")
      expect(att.id).to eq("1234")
    end

    it "treats numeric body as id when index is set (id was nil)" do
      att = open_with(attrs: { option: "0" }, body: "1234")
      expect(att.id).to eq("1234")
      expect(att.index).to eq("0")
    end
  end

  describe "#apply_body_content (via #on_open body+attrs combinations)" do
    it "uses body as filename when id is set and filename is nil" do
      att = open_with(attrs: { id: "42" }, body: "image.jpg")
      expect(att.id).to eq("42")
      expect(att.filename).to eq("image.jpg")
    end

    it "ignores body when id is set AND filename is set" do
      att = open_with(attrs: { id: "42", filename: "doc.pdf" }, body: "ignored.jpg")
      expect(att.filename).to eq("doc.pdf")
    end

    it "uses non-numeric body as id when id is nil and index is nil" do
      att = open_with(body: "image.jpg")
      expect(att.id).to eq("image.jpg")
      expect(att.filename).to be_nil
    end

    it "uses body as filename when id is nil, index is set, body is non-numeric" do
      att = open_with(attrs: { option: "0" }, body: "image.jpg")
      expect(att.index).to eq("0")
      expect(att.filename).to eq("image.jpg")
    end

    it "uses body as id when id is nil, index is set, body is numeric" do
      att = open_with(attrs: { option: "0" }, body: "1234")
      expect(att.id).to eq("1234")
      expect(att.index).to eq("0")
    end

    it "leaves filename nil when body is nil and id is set" do
      handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:, tokens: nil)
      expect(document.children.first.filename).to be_nil
    end
  end

  describe "#normalize_attrs (via #on_open attribute handling)" do
    it "strips whitespace-only :id, falling through to :msg-derived id" do
      att = open_with(attrs: { id: "   ", msg: "9876" })
      expect(att.id).to eq("9876")
    end

    it "strips whitespace-only :filename to nil" do
      att = open_with(attrs: { id: "42", filename: "   " })
      expect(att.filename).to be_nil
    end

    it "strips whitespace-only :alt to nil" do
      att = open_with(attrs: { id: "42", alt: "\t " })
      expect(att.alt).to be_nil
    end

    it "preserves a non-blank :id verbatim" do
      att = open_with(attrs: { id: "42" })
      expect(att.id).to eq("42")
    end
  end

  describe "#presence (via #on_open value normalization)" do
    it "treats nil values as absent" do
      handler.on_open(
        token: tag_start(attrs: { id: nil, msg: "9876" }),
        context:,
        registry:,
        tokens: nil,
      )
      expect(document.children.first.id).to eq("9876")
    end

    it "strips surrounding whitespace from string values" do
      att = open_with(attrs: { id: "  42  " })
      expect(att.id).to eq("42")
    end

    it "treats whitespace-only strings as absent" do
      att = open_with(attrs: { id: "   ", msg: "9876" })
      expect(att.id).to eq("9876")
    end

    it "treats whitespace-only body as nil filename" do
      att = open_with(attrs: { option: "0" }, body: "   ")
      expect(att.filename).to be_nil
    end
  end

  describe "#preferred_id (via #on_open id+msg combinations)" do
    it "returns :msg when present" do
      att = open_with(attrs: { msg: "9876", id: "2" })
      expect(att.id).to eq("9876")
    end

    it "falls back to :id when :msg is nil" do
      handler.on_open(
        token: tag_start(attrs: { msg: nil, id: "42" }),
        context:,
        registry:,
        tokens: nil,
      )
      expect(document.children.first.id).to eq("42")
    end

    it "falls back to :id when :msg is whitespace-only (treated as nil)" do
      att = open_with(attrs: { msg: "   ", id: "42" })
      expect(att.id).to eq("42")
    end

    it "leaves id nil when both :msg and :id are absent" do
      handler.on_open(token: tag_start(attrs: {}), context:, registry:, tokens: nil)
      expect(document.children.first.id).to be_nil
    end

    it "treats whitespace-only :id as absent (falls through to nil)" do
      att = open_with(attrs: { msg: nil, id: "   " })
      expect(att.id).to be_nil
    end
  end

  describe "#preferred_index (via #on_open index/id/msg combinations)" do
    it "returns :index when present, regardless of :msg/:id" do
      att = open_with(attrs: { index: "7", id: "2", msg: "99" })
      expect(att.index).to eq("7")
    end

    it "uses :id as the SMF-style index when :msg is present" do
      att = open_with(attrs: { id: "2", msg: "99" })
      expect(att.index).to eq("2")
    end

    it "does NOT use :id as index when :msg is absent" do
      att = open_with(attrs: { id: "2" })
      expect(att.index).to be_nil
    end

    it "leaves index nil when no relevant attribute is present" do
      att = open_with(attrs: { id: "1" }) # only id, no msg/index
      expect(att.index).to be_nil
    end

    it "treats whitespace-only :index as absent (falls through to :msg-based :id)" do
      att = open_with(attrs: { index: "   ", id: "2", msg: "99" })
      expect(att.index).to eq("2")
    end

    it "treats whitespace-only :id as absent in the SMF-style fallback" do
      att = open_with(attrs: { id: "   ", msg: "99" })
      expect(att.index).to be_nil
    end

    it "does not use :id as index when :msg key exists with nil value" do
      handler.on_open(
        token: tag_start(attrs: { msg: nil, id: "2" }),
        context:,
        registry:,
        tokens: nil,
      )
      expect(document.children.first.index).to be_nil
    end

    it "leaves index nil when :msg is present but :id key is entirely missing from attrs" do
      # attrs[:id] returns nil for an absent key — branch must tolerate that
      # rather than raising (e.g. via .fetch).
      att = open_with(attrs: { msg: "99" })
      expect(att.index).to be_nil
    end
  end

  describe "#collect_content (via #on_open with various token streams)" do
    it "returns nil when tokens is nil (no body to collect)" do
      handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:, tokens: nil)
      expect(document.children.first.filename).to be_nil
    end

    it "returns nil when no matching closing tag is in the peek window" do
      tokens = tokens_for(text_token("body without closer"))
      handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:, tokens:)
      expect(document.children.first.filename).to be_nil
    end

    it "returns the collected body when the closing tag is ahead" do
      att = open_with(attrs: { id: "42" }, body: "doc.pdf")
      expect(att.filename).to eq("doc.pdf")
    end
  end

  describe "#on_close" do
    it "appends the closing-tag source as text (it leaked past the collector)" do
      token = tag_end

      handler.on_close(token:, context:, registry:)

      expect(document.children.first).to be_a(Markbridge::AST::Text)
      expect(document.children.first.text).to eq("[/attachment]")
    end

    it "treats an omitted tokens kwarg the same as tokens: nil" do
      expect { handler.on_close(token: tag_end, context:, registry:) }.not_to raise_error
    end
  end

  describe "#closing_tag_ahead? (via #on_open token-stream peek)" do
    it "collects body when closing tag is in the peek window",
       mutant_expression:
         "Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#closing_tag_ahead?" do
      att = open_with(body: "body")
      expect(att.id).to eq("body")
    end

    it "skips collection when only a different-tag closing token is ahead",
       mutant_expression:
         "Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#closing_tag_ahead?" do
      tokens = tokens_for(tag_end(tag: "code"))
      handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:, tokens:)
      # Body wasn't collected; only attribute-derived id is used
      expect(document.children.first.id).to eq("42")
      expect(document.children.first.filename).to be_nil
    end

    it "skips collection when no TagEndToken is ahead at all",
       mutant_expression:
         "Markbridge::Parsers::BBCode::Handlers::AttachmentHandler#closing_tag_ahead?" do
      tokens = tokens_for(text_token("just text with no closer"))
      handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:, tokens:)
      expect(document.children.first.id).to eq("42")
      expect(document.children.first.filename).to be_nil
    end
  end
end
