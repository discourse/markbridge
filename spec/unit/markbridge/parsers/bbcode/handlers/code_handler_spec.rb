# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::CodeHandler do
  describe "#initialize" do
    it "exposes AST::Code as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Code)
    end

    it "is a RawHandler subclass (body content isn't re-parsed as BBCode)" do
      expect(described_class.new).to be_a(Markbridge::Parsers::BBCode::Handlers::RawHandler)
    end
  end

  # Exercised through #on_open (the public API); the examples live under
  # this describe so mutant matches them to the subject.
  describe "#create_element" do
    let(:handler) { described_class.new }
    let(:document) { Markbridge::AST::Document.new }
    let(:context) { Markbridge::Parsers::BBCode::ParserState.new(document) }
    let(:registry) { Markbridge::Parsers::BBCode::HandlerRegistry.new }

    let(:token_queue_class) do
      Class.new do
        def initialize(tokens)
          @tokens = tokens
        end

        def next_token
          @tokens.shift
        end
      end
    end

    def parse_tag(tag, attrs: {}, content: nil)
      open_token =
        Markbridge::Parsers::BBCode::TagStartToken.new(tag:, attrs:, pos: 0, source: "[#{tag}]")
      tokens = []
      tokens << Markbridge::Parsers::BBCode::TextToken.new(text: content, pos: 0) if content
      tokens << Markbridge::Parsers::BBCode::TagEndToken.new(tag:, pos: 0, source: "[/#{tag}]")

      handler.on_open(token: open_token, context:, registry:, tokens: token_queue_class.new(tokens))
      document.children.first
    end

    it "sets block on the element for code" do
      expect(parse_tag("code", content: "x").block).to be true
    end

    it "sets block on the element for pre" do
      expect(parse_tag("pre", content: "x").block).to be true
    end

    it "leaves block nil for tt (inline teletype)" do
      expect(parse_tag("tt", content: "x").block).to be_nil
    end

    it "extracts the language from the option attribute" do
      expect(parse_tag("code", attrs: { option: "ruby" }).language).to eq("ruby")
    end

    it "extracts the language from the lang attribute" do
      expect(parse_tag("code", attrs: { lang: "python" }).language).to eq("python")
    end

    it "prefers lang over option when both are present" do
      expect(parse_tag("code", attrs: { lang: "ruby", option: "python" }).language).to eq("ruby")
    end

    it "appends the collected content as a Text child" do
      element = parse_tag("code", content: "puts 1")
      expect(element.children.first.text).to eq("puts 1")
    end

    it "does not append a Text child when the content is empty" do
      expect(parse_tag("code").children).to be_empty
    end
  end
end
