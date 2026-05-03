# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::ParagraphHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "creates a Paragraph element and returns it so children get processed inside" do
      result = handler.process(element: build_element("<p>text</p>"), parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Paragraph)
      expect(result).to eq(parent.children[0])
    end
  end

  describe "#element_class" do
    it "returns AST::Paragraph" do
      expect(handler.element_class).to eq(Markbridge::AST::Paragraph)
    end
  end
end
