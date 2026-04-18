# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::ListItemHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::List.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "creates a ListItem element and returns it so children get processed inside" do
      result = handler.process(element: build_element("<li>text</li>"), parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::ListItem)
      expect(result).to eq(parent.children[0])
    end
  end

  describe "#element_class" do
    it "returns AST::ListItem" do
      expect(handler.element_class).to eq(Markbridge::AST::ListItem)
    end
  end
end
