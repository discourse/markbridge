# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::TableCellHandler do
  let(:parent) { Markbridge::AST::TableRow.new }
  let(:handler) { described_class.new }

  describe "#process" do
    it "creates a non-header cell for <td>" do
      node = Nokogiri::HTML.fragment("<table><tr><td>x</td></tr></table>").at_css("td")

      result = handler.process(element: node, parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::TableCell)
      expect(parent.children[0].header?).to be false
      expect(result).to eq(parent.children[0])
    end

    it "creates a header cell for <th>" do
      node = Nokogiri::HTML.fragment("<table><tr><th>x</th></tr></table>").at_css("th")

      result = handler.process(element: node, parent:)

      expect(parent.children[0].header?).to be true
      expect(result).to eq(parent.children[0])
    end

    it "handles case-insensitive tag names" do
      node = Nokogiri.XML("<TH>x</TH>").root

      handler.process(element: node, parent:)

      expect(parent.children[0].header?).to be true
    end
  end

  describe "#process with spans" do
    it "reads colspan and rowspan" do
      node =
        Nokogiri::HTML.fragment(
          %(<table><tr><td colspan="2" rowspan="3">x</td></tr></table>),
        ).at_css("td")

      handler.process(element: node, parent:)

      expect(parent.children[0].colspan).to eq(2)
      expect(parent.children[0].rowspan).to eq(3)
    end
  end

  describe "#element_class" do
    it "returns AST::TableCell" do
      expect(handler.element_class).to eq(Markbridge::AST::TableCell)
    end
  end
end
