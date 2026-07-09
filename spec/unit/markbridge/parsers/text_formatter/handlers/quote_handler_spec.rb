# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::QuoteHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "populates Quote fields from XML attributes" do
      xml = '<QUOTE author="Alice" post_id="42" topic_id="7" username="alice" user_id="12"/>'

      result = handler.process(element: build_element(xml), parent:)

      quote = parent.children[0]
      expect(quote).to be_a(Markbridge::AST::Quote)
      expect(quote.author).to eq("Alice")
      expect(quote.post_id).to eq(42)
      expect(quote.topic_id).to eq(7)
      expect(quote.username).to eq("alice")
      expect(quote.user_id).to eq(12)
      expect(result).to eq(quote)
    end

    it "maps post_id to the id field, not the Discourse post number" do
      handler.process(element: build_element('<QUOTE post_id="9001"/>'), parent:)

      quote = parent.children[0]
      expect(quote.post_id).to eq(9001)
      expect(quote.post_number).to be_nil
    end

    it "feeds a bare topic attribute into topic_id" do
      # A topic reference is an id in every dialect we know.
      handler.process(element: build_element('<QUOTE topic="456"/>'), parent:)

      expect(parent.children[0].topic_id).to eq(456)
    end

    it "prefers topic_id over a bare topic attribute" do
      handler.process(element: build_element('<QUOTE topic_id="1" topic="2"/>'), parent:)

      expect(parent.children[0].topic_id).to eq(1)
    end

    it "deliberately ignores a bare post attribute (id-or-number is dialect-unknowable)" do
      handler.process(element: build_element('<QUOTE post="123"/>'), parent:)

      quote = parent.children[0]
      expect(quote.post_id).to be_nil
      expect(quote.post_number).to be_nil
    end

    it "drops non-numeric id attributes instead of storing garbage" do
      handler.process(
        element: build_element('<QUOTE post_id="abc" topic_id="1x" user_id=""/>'),
        parent:,
      )

      quote = parent.children[0]
      expect(quote.post_id).to be_nil
      expect(quote.topic_id).to be_nil
      expect(quote.user_id).to be_nil
    end

    it "leaves all fields nil when no attributes are present" do
      handler.process(element: build_element("<QUOTE/>"), parent:)

      quote = parent.children[0]
      expect(quote.author).to be_nil
      expect(quote.post_id).to be_nil
      expect(quote.post_number).to be_nil
      expect(quote.topic_id).to be_nil
      expect(quote.username).to be_nil
      expect(quote.user_id).to be_nil
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
