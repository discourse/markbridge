# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::VoidHandler do
  let(:parent) { Markbridge::AST::Document.new }
  let(:node) { instance_double(Nokogiri::XML::Element, children: []) }

  describe "#process" do
    it "creates an element of the specified class and adds it to parent" do
      handler = described_class.new(Markbridge::AST::HorizontalRule)

      handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::HorizontalRule)
    end

    it "returns nil so the parser skips child traversal" do
      handler = described_class.new(Markbridge::AST::LineBreak)

      result = handler.process(element: node, parent:)

      expect(result).to be_nil
    end

    it "honors the configured element class across instances" do
      line_break_handler = described_class.new(Markbridge::AST::LineBreak)
      hr_handler = described_class.new(Markbridge::AST::HorizontalRule)

      line_break_handler.process(element: node, parent:)
      hr_handler.process(element: node, parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::LineBreak)
      expect(parent.children[1]).to be_a(Markbridge::AST::HorizontalRule)
    end
  end

  describe "#element_class" do
    it "returns the element class given to the constructor" do
      handler = described_class.new(Markbridge::AST::HorizontalRule)

      expect(handler.element_class).to eq(Markbridge::AST::HorizontalRule)
    end
  end
end
