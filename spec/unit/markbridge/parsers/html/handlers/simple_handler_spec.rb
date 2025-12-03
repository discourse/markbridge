# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::SimpleHandler do
  let(:parent) { Markbridge::AST::Document.new }

  describe "#process" do
    it "creates an element of the specified class" do
      handler = described_class.new(Markbridge::AST::Bold)
      node = instance_double(Nokogiri::XML::Element, children: [])

      result = handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Bold)
      expect(result).to be_a(Markbridge::AST::Bold)
    end

    it "returns element to signal children should be processed" do
      handler = described_class.new(Markbridge::AST::Bold)
      node = instance_double(Nokogiri::XML::Element, children: [])

      result = handler.process(element: node, parent:)

      expect(result).to eq(parent.children.last)
    end

    it "adds the created element to parent" do
      handler = described_class.new(Markbridge::AST::Italic)
      node = instance_double(Nokogiri::XML::Element, children: [])

      handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Italic)
    end

    it "works with different element classes" do
      underline_handler = described_class.new(Markbridge::AST::Underline)
      node = instance_double(Nokogiri::XML::Element, children: [])

      underline_handler.process(element: node, parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::Underline)
    end
  end

  describe "#element_class" do
    it "returns the element class" do
      handler = described_class.new(Markbridge::AST::Bold)

      expect(handler.element_class).to eq(Markbridge::AST::Bold)
    end
  end
end
