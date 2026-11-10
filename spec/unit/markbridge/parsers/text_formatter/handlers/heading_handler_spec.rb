# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::HeadingHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "creates a heading with the level from the element name and returns it" do
      result = handler.process(element: build_element("<H3><s>### </s>Title</H3>"), parent:)

      expect(parent.children).to eq([result])
      expect(result).to be_a(Markbridge::AST::Heading)
      expect(result.level).to eq(3)
    end

    it "reads every level" do
      levels =
        (1..6).map do |level|
          handler.process(element: build_element("<H#{level}/>"), parent:).level
        end

      expect(levels).to eq([1, 2, 3, 4, 5, 6])
    end
  end

  describe "#element_class" do
    it "is the heading" do
      expect(handler.element_class).to eq(Markbridge::AST::Heading)
    end
  end
end
