# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::TableHandler do
  let(:parent) { Markbridge::AST::Document.new }
  let(:handler) { described_class.new }

  describe "#process" do
    it "creates a Table element" do
      node = instance_double(Nokogiri::XML::Element, name: "table")

      result = handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Table)
      expect(result).to eq(parent.children[0])
    end
  end

  describe "#element_class" do
    it "returns AST::Table" do
      expect(handler.element_class).to eq(Markbridge::AST::Table)
    end
  end
end
