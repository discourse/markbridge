# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::ListHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "creates an unordered list when the type attribute is absent" do
      result = handler.process(element: build_element("<LIST/>"), parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::List)
      expect(parent.children[0].ordered?).to be false
      expect(result).to eq(parent.children[0])
    end

    it "creates an unordered list for bullet style 'disc'" do
      handler.process(element: build_element('<LIST type="disc"/>'), parent:)
      expect(parent.children[0].ordered?).to be false
    end

    it "creates an unordered list for bullet style 'circle'" do
      handler.process(element: build_element('<LIST type="circle"/>'), parent:)
      expect(parent.children[0].ordered?).to be false
    end

    it "creates an unordered list for bullet style 'square'" do
      handler.process(element: build_element('<LIST type="square"/>'), parent:)
      expect(parent.children[0].ordered?).to be false
    end

    it "creates an unordered list when type is the empty string" do
      handler.process(element: build_element('<LIST type=""/>'), parent:)
      expect(parent.children[0].ordered?).to be false
    end

    it "creates an ordered list for numeric type '1'" do
      handler.process(element: build_element('<LIST type="1"/>'), parent:)
      expect(parent.children[0].ordered?).to be true
    end

    it "creates an ordered list for alpha type 'a'" do
      handler.process(element: build_element('<LIST type="a"/>'), parent:)
      expect(parent.children[0].ordered?).to be true
    end

    it "normalizes uppercase XML attribute names to lowercase symbol keys" do
      handler.process(element: build_element('<LIST TYPE="1"/>'), parent:)
      expect(parent.children[0].ordered?).to be true
    end
  end

  describe "#element_class" do
    it "returns AST::List" do
      expect(handler.element_class).to eq(Markbridge::AST::List)
    end
  end
end
