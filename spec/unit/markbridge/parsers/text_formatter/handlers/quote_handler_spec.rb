# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::QuoteHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "populates Quote fields from XML attributes" do
      xml = '<QUOTE author="Alice" post_id="42" topic_id="7" username="alice"/>'

      result = handler.process(element: build_element(xml), parent:)

      quote = parent.children[0]
      expect(quote).to be_a(Markbridge::AST::Quote)
      expect(quote.author).to eq("Alice")
      expect(quote.post).to eq("42")
      expect(quote.topic).to eq("7")
      expect(quote.username).to eq("alice")
      expect(result).to eq(quote)
    end

    it "prefers post_id over post when both are present" do
      handler.process(element: build_element('<QUOTE post_id="primary" post="fallback"/>'), parent:)

      expect(parent.children[0].post).to eq("primary")
    end

    it "falls back to post when post_id is absent" do
      handler.process(element: build_element('<QUOTE post="only"/>'), parent:)

      expect(parent.children[0].post).to eq("only")
    end

    it "prefers topic_id over topic when both are present" do
      handler.process(
        element: build_element('<QUOTE topic_id="primary" topic="fallback"/>'),
        parent:,
      )

      expect(parent.children[0].topic).to eq("primary")
    end

    it "falls back to topic when topic_id is absent" do
      handler.process(element: build_element('<QUOTE topic="only"/>'), parent:)

      expect(parent.children[0].topic).to eq("only")
    end

    it "leaves all fields nil when no attributes are present" do
      handler.process(element: build_element("<QUOTE/>"), parent:)

      quote = parent.children[0]
      expect(quote.author).to be_nil
      expect(quote.post).to be_nil
      expect(quote.topic).to be_nil
      expect(quote.username).to be_nil
    end

    it "normalizes uppercase XML attribute names to lowercase symbol keys" do
      handler.process(element: build_element('<QUOTE AUTHOR="Alice" USERNAME="alice"/>'), parent:)

      expect(parent.children[0].author).to eq("Alice")
      expect(parent.children[0].username).to eq("alice")
    end
  end

  describe "#element_class" do
    it "returns AST::Quote" do
      expect(handler.element_class).to eq(Markbridge::AST::Quote)
    end
  end
end
