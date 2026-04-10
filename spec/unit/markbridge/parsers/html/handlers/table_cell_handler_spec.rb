# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::TableCellHandler do
  let(:parent) { Markbridge::AST::TableRow.new }
  let(:handler) { described_class.new }

  describe "#process" do
    it "creates a non-header cell for <td>" do
      node = instance_double(Nokogiri::XML::Element, name: "td")

      result = handler.process(element: node, parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::TableCell)
      expect(parent.children[0].header?).to be false
      expect(result).to eq(parent.children[0])
    end

    it "creates a header cell for <th>" do
      node = instance_double(Nokogiri::XML::Element, name: "th")

      result = handler.process(element: node, parent:)

      expect(parent.children[0].header?).to be true
      expect(result).to eq(parent.children[0])
    end

    it "handles case-insensitive tag names" do
      node = instance_double(Nokogiri::XML::Element, name: "TH")

      handler.process(element: node, parent:)

      expect(parent.children[0].header?).to be true
    end
  end

  describe "#element_class" do
    it "returns AST::TableCell" do
      expect(handler.element_class).to eq(Markbridge::AST::TableCell)
    end
  end
end
