# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::UrlHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "creates a Url node with href pulled from the url attribute" do
      result = handler.process(element: build_element('<URL url="https://example.org"/>'), parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::Url)
      expect(parent.children[0].href).to eq("https://example.org")
      expect(result).to eq(parent.children[0])
    end

    it "leaves href nil when the url attribute is absent" do
      handler.process(element: build_element("<URL/>"), parent:)

      expect(parent.children[0].href).to be_nil
    end

    it "normalizes uppercase XML attribute names to lowercase symbol keys" do
      handler.process(element: build_element('<URL URL="https://example.org"/>'), parent:)

      expect(parent.children[0].href).to eq("https://example.org")
    end
  end

  describe "#element_class" do
    it "returns AST::Url" do
      expect(handler.element_class).to eq(Markbridge::AST::Url)
    end
  end
end
