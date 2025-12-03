# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::UrlHandler do
  let(:parent) { Markbridge::AST::Document.new }

  describe "#process" do
    it "creates a Url element with href" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": "http://example.org")

      result = handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Url)
      expect(parent.children[0].href).to eq("http://example.org")
      expect(result).to eq(parent.children[0])
    end

    it "returns element to signal children should be processed" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": "http://example.org")

      result = handler.process(element: node, parent:)

      expect(result).to be_a(Markbridge::AST::Url)
    end

    it "handles nil href" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": nil)

      handler.process(element: node, parent:)

      expect(parent.children[0].href).to be_nil
    end
  end

  describe "#element_class" do
    it "returns AST::Url" do
      handler = described_class.new

      expect(handler.element_class).to eq(Markbridge::AST::Url)
    end
  end
end
