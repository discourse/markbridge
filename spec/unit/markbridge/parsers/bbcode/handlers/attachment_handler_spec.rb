# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::AttachmentHandler do
  let(:handler) { described_class.new }
  let(:document) { Markbridge::AST::Document.new }
  let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.new }
  let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }

  # Test subclass that exposes the private helpers for direct unit tests.
  let(:exposed_handler_class) do
    Class.new(described_class) do
      public :collect_content,
             :closing_tag_ahead?,
             :build_attachment,
             :normalize_attrs,
             :apply_body_content,
             :preferred_id,
             :preferred_index,
             :presence,
             :numeric?
    end
  end
  let(:exposed_handler) { exposed_handler_class.new }

  def tag_start(tag: "attachment", attrs: {}, source: nil)
    Markbridge::Parsers::BBCode::TagStartToken.new(
      tag:,
      attrs:,
      pos: 0,
      source: source || "[#{tag}]",
    )
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

  describe "#initialize" do
    it "exposes AST::Attachment as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Attachment)
    end

    it "uses a default RawContentCollector instance (so #collect works with token streams)" do
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TextToken.new(text: "body-content", pos: 0),
          Markbridge::Parsers::BBCode::TagEndToken.new(
            tag: "attachment",
            pos: 12,
            source: "[/attachment]",
          ),
        )

      described_class.new.on_open(
        token: tag_start(attrs: { option: "0" }),
        context:,
        registry:,
        tokens:,
      )

      expect(document.children.first.filename).to eq("body-content")
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

      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TagEndToken.new(
            tag: "attachment",
            pos: 0,
            source: "[/attachment]",
          ),
        )

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
    it "parses phpBB-style index + filename body" do
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TextToken.new(text: "image.jpg", pos: 14),
          Markbridge::Parsers::BBCode::TagEndToken.new(
            tag: "attachment",
            pos: 23,
            source: "[/attachment]",
          ),
        )

      handler.on_open(token: tag_start(attrs: { option: "0" }), context:, registry:, tokens:)

      att = document.children.first
      expect(att).to be_a(Markbridge::AST::Attachment)
      expect(att.id).to be_nil
      expect(att.index).to eq("0")
      expect(att.filename).to eq("image.jpg")
    end

    it "parses vBulletin-style id from numeric body when option is non-numeric" do
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TextToken.new(text: "1234", pos: 0),
          Markbridge::Parsers::BBCode::TagEndToken.new(tag: "attach", pos: 4, source: "[/ATTACH]"),
        )

      handler.on_open(
        token: tag_start(tag: "attach", attrs: { option: "CONFIG" }),
        context:,
        registry:,
        tokens:,
      )

      att = document.children.first
      expect(att.id).to eq("1234")
      expect(att.index).to be_nil
    end

    it "parses XenForo-style id with type and alt" do
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TextToken.new(text: "5678", pos: 0),
          Markbridge::Parsers::BBCode::TagEndToken.new(tag: "attach", pos: 4, source: "[/ATTACH]"),
        )

      handler.on_open(
        token: tag_start(tag: "attach", attrs: { type: "full", alt: "diagram" }),
        context:,
        registry:,
        tokens:,
      )

      att = document.children.first
      expect(att.id).to eq("5678")
      expect(att.alt).to eq("diagram")
    end

    it "handles SMF-style attributes with no body" do
      handler.on_open(
        token: tag_start(tag: "attach", attrs: { id: "2", msg: "9876" }),
        context:,
        registry:,
        tokens: tokens_for,
      )

      att = document.children.first
      expect(att.id).to eq("9876")
      expect(att.index).to eq("2")
      expect(att.filename).to be_nil
    end

    it "still works with no tokens available at all (treats as attribute-only)" do
      handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:, tokens: nil)

      att = document.children.first
      expect(att.id).to eq("42")
      expect(att.filename).to be_nil
    end

    it "treats an omitted tokens kwarg the same as tokens: nil" do
      handler.on_open(token: tag_start(attrs: { id: "42" }), context:, registry:)

      att = document.children.first
      expect(att.id).to eq("42")
    end

    it "uses a default RawContentCollector when one is not supplied" do
      # Calling described_class.new without :collector exercises the default.
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TextToken.new(text: "body-content", pos: 0),
          Markbridge::Parsers::BBCode::TagEndToken.new(
            tag: "attachment",
            pos: 12,
            source: "[/attachment]",
          ),
        )

      described_class.new.on_open(
        token: tag_start(attrs: { option: "0" }),
        context:,
        registry:,
        tokens:,
      )

      expect(document.children.first.filename).to eq("body-content")
    end

    it "trims whitespace-only attribute values via normalize_attrs before building" do
      # With :id whitespace, presence strips it to nil, so preferred_id falls
      # through. Without normalize_attrs, the whitespace would leak through.
      handler.on_open(
        token: tag_start(attrs: { id: "   ", msg: "9876" }),
        context:,
        registry:,
        tokens: nil,
      )

      att = document.children.first
      expect(att.id).to eq("9876")
      expect(att.index).to be_nil
    end

    it "normalizes whitespace-only :filename and :alt to nil (not passed verbatim)" do
      handler.on_open(
        token: tag_start(attrs: { id: "42", filename: "   ", alt: "\t " }),
        context:,
        registry:,
        tokens: nil,
      )

      att = document.children.first
      expect(att.filename).to be_nil
      expect(att.alt).to be_nil
    end

    it "preserves an explicit :filename attribute when id is also set" do
      handler.on_open(
        token: tag_start(attrs: { id: "42", filename: "doc.pdf" }),
        context:,
        registry:,
        tokens: nil,
      )

      expect(document.children.first.filename).to eq("doc.pdf")
    end

    it "treats a whitespace-only body as nil (not as an empty filename)" do
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TextToken.new(text: "   ", pos: 0),
          Markbridge::Parsers::BBCode::TagEndToken.new(
            tag: "attachment",
            pos: 3,
            source: "[/attachment]",
          ),
        )

      handler.on_open(token: tag_start(attrs: { option: "0" }), context:, registry:, tokens:)

      att = document.children.first
      expect(att.filename).to be_nil
    end
  end

  describe "#on_close" do
    it "appends the closing-tag source as text (it leaked past the collector)" do
      token =
        Markbridge::Parsers::BBCode::TagEndToken.new(
          tag: "attachment",
          pos: 0,
          source: "[/attachment]",
        )

      handler.on_close(token:, context:, registry:)

      expect(document.children.first).to be_a(Markbridge::AST::Text)
      expect(document.children.first.text).to eq("[/attachment]")
    end

    it "treats an omitted tokens kwarg the same as tokens: nil" do
      token =
        Markbridge::Parsers::BBCode::TagEndToken.new(
          tag: "attachment",
          pos: 0,
          source: "[/attachment]",
        )

      expect { handler.on_close(token:, context:, registry:) }.not_to raise_error
    end
  end

  describe "#presence" do
    it "returns nil for nil" do
      expect(exposed_handler.presence(nil)).to be_nil
    end

    it "returns the string unchanged when it has non-whitespace content" do
      expect(exposed_handler.presence("hello")).to eq("hello")
    end

    it "strips surrounding whitespace on strings" do
      expect(exposed_handler.presence("  hello  ")).to eq("hello")
    end

    it "returns nil for an empty string" do
      expect(exposed_handler.presence("")).to be_nil
    end

    it "returns nil for a whitespace-only string" do
      expect(exposed_handler.presence("   \t ")).to be_nil
    end

    it "returns non-string values unchanged" do
      expect(exposed_handler.presence(42)).to eq(42)
      expect(exposed_handler.presence(:symbol)).to eq(:symbol)
    end
  end

  describe "#numeric?" do
    it "is true for a purely numeric string" do
      expect(exposed_handler.numeric?("123")).to be true
    end

    it "is false for strings with non-digit characters" do
      expect(exposed_handler.numeric?("12a3")).to be false
    end

    it "is false for a string with leading whitespace" do
      expect(exposed_handler.numeric?(" 123")).to be false
    end

    it "is false for a string with trailing whitespace" do
      expect(exposed_handler.numeric?("123 ")).to be false
    end

    it "is false for empty string" do
      expect(exposed_handler.numeric?("")).to be false
    end

    it "is false for non-string values (no coercion)" do
      expect(exposed_handler.numeric?(123)).to be false
      expect(exposed_handler.numeric?(nil)).to be false
    end
  end

  describe "#normalize_attrs" do
    it "applies presence to each value, dropping blanks" do
      result = exposed_handler.normalize_attrs(a: "x", b: "  ", c: nil, d: "  y  ")

      expect(result).to eq(a: "x", b: nil, c: nil, d: "y")
    end
  end

  describe "#preferred_id" do
    it "returns :msg when present" do
      expect(exposed_handler.preferred_id(msg: "9876", id: "2")).to eq("9876")
    end

    it "falls back to :id when :msg is nil" do
      expect(exposed_handler.preferred_id(msg: nil, id: "42")).to eq("42")
    end

    it "falls back to :id when :msg is whitespace-only" do
      # Already passed through normalize_attrs in the public path, but
      # the helper itself must also tolerate an un-normalized blank.
      expect(exposed_handler.preferred_id(msg: "   ", id: "42")).to eq("42")
    end

    it "returns nil when both are missing" do
      expect(exposed_handler.preferred_id({})).to be_nil
    end

    it "treats a whitespace-only :id as absent (falls through to nil)" do
      expect(exposed_handler.preferred_id(msg: nil, id: "   ")).to be_nil
    end
  end

  describe "#preferred_index" do
    it "returns :index when present, regardless of :msg" do
      expect(exposed_handler.preferred_index(index: "7", id: "2", msg: "99")).to eq("7")
    end

    it "uses :id as the SMF-style index when :msg is present" do
      expect(exposed_handler.preferred_index(id: "2", msg: "99")).to eq("2")
    end

    it "does not use :id as index when :msg is absent" do
      expect(exposed_handler.preferred_index(id: "2")).to be_nil
    end

    it "returns nil when no relevant attribute is present" do
      expect(exposed_handler.preferred_index({})).to be_nil
    end

    it "treats a whitespace-only :index as absent (falls through to :msg-based :id)" do
      expect(exposed_handler.preferred_index(index: "   ", id: "2", msg: "99")).to eq("2")
    end

    it "treats a whitespace-only :id as absent when computing the SMF-style fallback" do
      expect(exposed_handler.preferred_index(id: "   ", msg: "99")).to be_nil
    end

    it "does not use :id as index when :msg key exists but its value is nil" do
      # After normalize_attrs, a blank :msg becomes nil. The branch should
      # treat this as "no SMF pairing".
      expect(exposed_handler.preferred_index(msg: nil, id: "2")).to be_nil
    end

    it "returns nil when :msg is present but :id key is not in the hash at all" do
      # attrs[:id] returns nil for a missing key; the branch must tolerate
      # that rather than raising (e.g. via .fetch).
      expect(exposed_handler.preferred_index(msg: "99")).to be_nil
    end
  end

  describe "#apply_body_content" do
    it "leaves id and filename unchanged when body is nil" do
      id, filename =
        exposed_handler.apply_body_content(body: nil, id: "5", index: nil, filename: "x")

      expect(id).to eq("5")
      expect(filename).to eq("x")
    end

    it "uses body as id when id and index are both nil (numeric body)" do
      id, filename =
        exposed_handler.apply_body_content(body: "1234", id: nil, index: nil, filename: nil)

      expect(id).to eq("1234")
      expect(filename).to be_nil
    end

    it "uses body as id when id and index are both nil (non-numeric body)" do
      # `id` takes the body even when it doesn't look numeric, because
      # without any other anchor the body is the best guess for a handle.
      id, filename =
        exposed_handler.apply_body_content(body: "image.jpg", id: nil, index: nil, filename: nil)

      expect(id).to eq("image.jpg")
      expect(filename).to be_nil
    end

    it "uses body as id when id is nil and body is numeric (index present)" do
      id, filename =
        exposed_handler.apply_body_content(body: "1234", id: nil, index: "0", filename: nil)

      expect(id).to eq("1234")
      expect(filename).to be_nil
    end

    it "uses body as filename when id is nil, index is present, body is non-numeric" do
      id, filename =
        exposed_handler.apply_body_content(body: "image.jpg", id: nil, index: "0", filename: nil)

      expect(id).to be_nil
      expect(filename).to eq("image.jpg")
    end

    it "uses body as filename when id is set and filename is nil" do
      id, filename =
        exposed_handler.apply_body_content(body: "image.jpg", id: "42", index: nil, filename: nil)

      expect(id).to eq("42")
      expect(filename).to eq("image.jpg")
    end

    it "keeps an existing filename when id is set" do
      id, filename =
        exposed_handler.apply_body_content(
          body: "ignored.jpg",
          id: "42",
          index: nil,
          filename: "original.jpg",
        )

      expect(id).to eq("42")
      expect(filename).to eq("original.jpg")
    end
  end

  describe "#closing_tag_ahead?" do
    it "is true when a matching TagEndToken is in the peek window" do
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TextToken.new(text: "x", pos: 0),
          Markbridge::Parsers::BBCode::TagEndToken.new(tag: "attach", pos: 1, source: "[/attach]"),
        )

      expect(exposed_handler.closing_tag_ahead?("attach", tokens)).to be true
    end

    it "is false when only a different-tag closing token is ahead" do
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TagEndToken.new(tag: "code", pos: 0, source: "[/code]"),
        )

      expect(exposed_handler.closing_tag_ahead?("attach", tokens)).to be false
    end

    it "is false when no TagEndToken is ahead" do
      tokens = tokens_for(Markbridge::Parsers::BBCode::TextToken.new(text: "just text", pos: 0))

      expect(exposed_handler.closing_tag_ahead?("attach", tokens)).to be false
    end

    it "is false on an empty token stream" do
      expect(exposed_handler.closing_tag_ahead?("attach", tokens_for)).to be false
    end
  end

  describe "#collect_content" do
    it "returns nil when tokens is nil" do
      expect(
        exposed_handler.collect_content(token: tag_start(tag: "attach"), tokens: nil),
      ).to be_nil
    end

    it "returns nil when no matching closing tag is ahead" do
      tokens = tokens_for(Markbridge::Parsers::BBCode::TextToken.new(text: "body", pos: 0))

      expect(exposed_handler.collect_content(token: tag_start(tag: "attach"), tokens:)).to be_nil
    end

    it "returns the collected body when the closing tag is ahead" do
      tokens =
        tokens_for(
          Markbridge::Parsers::BBCode::TextToken.new(text: "body", pos: 0),
          Markbridge::Parsers::BBCode::TagEndToken.new(tag: "attach", pos: 4, source: "[/attach]"),
        )

      expect(exposed_handler.collect_content(token: tag_start(tag: "attach"), tokens:)).to eq(
        "body",
      )
    end
  end
end
