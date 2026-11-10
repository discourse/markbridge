# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::SelfClosingHandler do
  let(:handler) { described_class.new(Markbridge::AST::HorizontalRule) }
  let(:parent) { Markbridge::AST::Document.new }

  describe "#process" do
    it "appends an instance of the element class and returns nil" do
      element = Nokogiri::XML.fragment("<HR><s>[hr]</s><e>[/hr]</e></HR>").children.first

      result = handler.process(element:, parent:)

      expect(result).to be_nil
      expect(parent.children.map(&:class)).to eq([Markbridge::AST::HorizontalRule])
    end
  end

  describe "#element_class" do
    it "returns the configured element class" do
      expect(handler.element_class).to eq(Markbridge::AST::HorizontalRule)
    end
  end
end
