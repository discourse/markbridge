# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler do
  let(:handler) { described_class.new(Markbridge::AST::Bold) }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "creates an instance of the configured element class and returns it" do
      result = handler.process(element: build_element("<B/>"), parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Bold)
      expect(result).to eq(parent.children[0])
    end

    it "works with different element classes" do
      italic_handler = described_class.new(Markbridge::AST::Italic)

      italic_handler.process(element: build_element("<I/>"), parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::Italic)
    end
  end

  describe "#element_class" do
    it "returns the configured element class" do
      expect(handler.element_class).to eq(Markbridge::AST::Bold)
    end
  end
end
