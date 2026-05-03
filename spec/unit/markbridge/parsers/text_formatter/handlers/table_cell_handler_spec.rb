# frozen_string_literal: true

require "nokogiri"

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::TableCellHandler do
  let(:parent) { Markbridge::AST::TableRow.new }
  let(:handler) { described_class.new }

  describe "#process" do
    it "creates a non-header cell for TD" do
      element = Nokogiri.XML("<TD>data</TD>").root

      result = handler.process(element:, parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::TableCell)
      expect(parent.children[0].header?).to be false
      expect(result).to eq(parent.children[0])
    end

    it "creates a header cell for TH" do
      element = Nokogiri.XML("<TH>header</TH>").root

      result = handler.process(element:, parent:)

      expect(parent.children[0].header?).to be true
      expect(result).to eq(parent.children[0])
    end

    it "treats lowercase <th> as a header cell (case-insensitive)" do
      # Kills `element.name.upcase == "TH"` → `element.name == "TH"`.
      # Without the upcase, a lowercase `th` would fail the equality
      # check and be classified as a data cell.
      element = Nokogiri.XML("<th>header</th>").root

      handler.process(element:, parent:)

      expect(parent.children[0].header?).to be true
    end
  end

  describe "#element_class" do
    it "returns AST::TableCell" do
      expect(handler.element_class).to eq(Markbridge::AST::TableCell)
    end
  end
end
