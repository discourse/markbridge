# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::ListHandler do
  let(:parent) { Markbridge::AST::Document.new }

  describe "#process" do
    it "creates an unordered list for <ul>" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, name: "ul")

      result = handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::List)
      expect(parent.children[0].ordered?).to be false
      expect(result).to eq(parent.children[0])
    end

    it "creates an ordered list for <ol>" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, name: "ol")

      result = handler.process(element: node, parent:)

      expect(parent.children[0].ordered?).to be true
      expect(result).to eq(parent.children[0])
    end

    it "returns element to signal children should be processed" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, name: "ul")

      result = handler.process(element: node, parent:)

      expect(result).to be_a(Markbridge::AST::List)
    end

    it "handles case-insensitive tag names" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, name: "OL")

      handler.process(element: node, parent:)

      expect(parent.children[0].ordered?).to be true
    end
  end

  describe "#element_class" do
    it "returns AST::List" do
      handler = described_class.new

      expect(handler.element_class).to eq(Markbridge::AST::List)
    end
  end
end
