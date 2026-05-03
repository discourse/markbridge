# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::UrlHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "creates a Url element with the href attribute" do
      result = handler.process(element: build_element('<a href="http://example.org">'), parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Url)
      expect(parent.children[0].href).to eq("http://example.org")
      expect(result).to eq(parent.children[0])
    end

    it "leaves href nil when the attribute is missing" do
      handler.process(element: build_element("<a>link</a>"), parent:)

      expect(parent.children[0].href).to be_nil
    end

    it "returns the created element so children can be processed into it" do
      result = handler.process(element: build_element('<a href="http://example.org">'), parent:)

      expect(result).to be_a(Markbridge::AST::Url)
    end
  end

  describe "#element_class" do
    it "returns AST::Url" do
      expect(handler.element_class).to eq(Markbridge::AST::Url)
    end
  end
end
