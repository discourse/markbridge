# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::QuoteHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "creates a Quote element carrying the cite attribute as author" do
      result =
        handler.process(
          element: build_element('<blockquote cite="http://example.org">q</blockquote>'),
          parent:,
        )

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Quote)
      expect(parent.children[0].author).to eq("http://example.org")
      expect(result).to eq(parent.children[0])
    end

    it "leaves author nil when the cite attribute is missing" do
      handler.process(element: build_element("<blockquote>q</blockquote>"), parent:)

      expect(parent.children[0].author).to be_nil
    end

    it "returns the created element so children can be processed into it" do
      result = handler.process(element: build_element("<blockquote>q</blockquote>"), parent:)

      expect(result).to be_a(Markbridge::AST::Quote)
    end
  end

  describe "#element_class" do
    it "returns AST::Quote" do
      expect(handler.element_class).to eq(Markbridge::AST::Quote)
    end
  end
end
