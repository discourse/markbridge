# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::SelfClosingHandler do
  let(:parent) { Markbridge::AST::Paragraph.new }

  describe "#initialize" do
    it "exposes the element_class via reader" do
      expect(described_class.new(Markbridge::AST::LineBreak).element_class).to eq(
        Markbridge::AST::LineBreak,
      )
    end
  end

  describe "#process" do
    it "appends a fresh instance of element_class to parent" do
      handler = described_class.new(Markbridge::AST::LineBreak)

      handler.process(element: nil, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children.first).to be_a(Markbridge::AST::LineBreak)
    end

    it "returns nil so the parser does not recurse into children" do
      handler = described_class.new(Markbridge::AST::LineBreak)

      expect(handler.process(element: nil, parent:)).to be_nil
    end

    it "produces a fresh instance on every call (not a shared object)" do
      handler = described_class.new(Markbridge::AST::HorizontalRule)

      handler.process(element: nil, parent:)
      handler.process(element: nil, parent:)

      expect(parent.children.size).to eq(2)
      expect(parent.children[0]).not_to equal(parent.children[1])
    end

    it "respects the configured element_class (HorizontalRule, not LineBreak)" do
      handler = described_class.new(Markbridge::AST::HorizontalRule)

      handler.process(element: nil, parent:)

      expect(parent.children.first).to be_a(Markbridge::AST::HorizontalRule)
      expect(parent.children.first).not_to be_a(Markbridge::AST::LineBreak)
    end
  end
end
