# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::RawContentCollector do
  let(:collector) { described_class.new }

  describe "#collect" do
    it "collects text until closing tag" do
      scanner = create_scanner(text_token("puts 'hello'"), tag_end_token("code", "[/code]"))

      result = collector.collect("code", scanner)
      expect(result).to be_a(Markbridge::Parsers::BBCode::RawContentResult)
      expect(result.content).to eq("puts 'hello'")
      expect(result.closed?).to be true
      expect(result.unclosed?).to be false
    end

    it "preserves nested tags of the same type" do
      scanner =
        create_scanner(
          text_token("outer "),
          tag_start_token("code", "[code]"),
          text_token("inner"),
          tag_end_token("code", "[/code]"),
          text_token(" content"),
          tag_end_token("code", "[/code]"),
        )

      result = collector.collect("code", scanner)
      expect(result.content).to eq("outer [code]inner[/code] content")
      expect(result.closed?).to be true
    end

    it "handles empty content" do
      scanner = create_scanner(tag_end_token("code", "[/code]"))

      result = collector.collect("code", scanner)
      expect(result.content).to eq("")
      expect(result.closed?).to be true
    end

    it "collects until no more tokens" do
      scanner = create_scanner(text_token("incomplete"))

      result = collector.collect("code", scanner)
      expect(result.content).to eq("incomplete")
      expect(result.closed?).to be false
      expect(result.unclosed?).to be true
    end

    it "preserves exact source text" do
      scanner =
        create_scanner(
          text_token("x = "),
          tag_start_token("b", "[b lang='test']"),
          text_token("value"),
          tag_end_token("b", "[/b]"),
          tag_end_token("code", "[/code]"),
        )

      result = collector.collect("code", scanner)
      expect(result.content).to eq("x = [b lang='test']value[/b]")
      expect(result.closed?).to be true
    end

    it "ignores other tag types" do
      scanner =
        create_scanner(
          text_token("text "),
          tag_start_token("b", "[b]"),
          text_token("bold"),
          tag_end_token("b", "[/b]"),
          text_token(" more"),
          tag_end_token("code", "[/code]"),
        )

      result = collector.collect("code", scanner)
      expect(result.content).to eq("text [b]bold[/b] more")
      expect(result.closed?).to be true
    end
  end

  private

  def create_scanner(*tokens)
    MockScanner.new(tokens)
  end

  def text_token(text)
    Markbridge::Parsers::BBCode::TextToken.new(text:, pos: 0)
  end

  def tag_start_token(tag, source)
    Markbridge::Parsers::BBCode::TagStartToken.new(tag:, attrs: {}, pos: 0, source:)
  end

  def tag_end_token(tag, source)
    Markbridge::Parsers::BBCode::TagEndToken.new(tag:, pos: 0, source:)
  end

  # Mock scanner that returns tokens from array
  class MockScanner
    def initialize(tokens)
      @tokens = tokens
      @index = 0
    end

    def next_token
      return nil if @index >= @tokens.size
      token = @tokens[@index]
      @index += 1
      token
    end
  end
end
