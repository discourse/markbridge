# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::TableRowHandler do
  let(:parent) { Markbridge::AST::Table.new }
  let(:handler) { described_class.new }

  describe "#process" do
    it "creates a TableRow element" do
      node = instance_double(Nokogiri::XML::Element, name: "tr")

      result = handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::TableRow)
      expect(result).to eq(parent.children[0])
    end
  end

  describe "#element_class" do
    it "returns AST::TableRow" do
      expect(handler.element_class).to eq(Markbridge::AST::TableRow)
    end
  end
end
