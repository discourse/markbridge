# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::VoidHandler do
  let(:handler) { described_class.new(Markbridge::AST::LineBreak) }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "appends an instance of the configured element class to the parent" do
      handler.process(element: build_element("<br>"), parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::LineBreak)
    end

    it "returns nil to signal children should not be processed" do
      result = handler.process(element: build_element("<br>"), parent:)

      expect(result).to be_nil
    end

    it "works with different element classes" do
      hr_handler = described_class.new(Markbridge::AST::HorizontalRule)

      hr_handler.process(element: build_element("<hr>"), parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::HorizontalRule)
    end
  end

  describe "#element_class" do
    it "returns the configured element class" do
      expect(handler.element_class).to eq(Markbridge::AST::LineBreak)
    end
  end
end
