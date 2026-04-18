# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::AttributeHandler do
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "passes the named attribute to the constructor under the matching param name" do
      handler = described_class.new(Markbridge::AST::Color, attribute: :color)

      result = handler.process(element: build_element('<COLOR color="red"/>'), parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::Color)
      expect(parent.children[0].color).to eq("red")
      expect(result).to eq(parent.children[0])
    end

    it "remaps to a different param name when explicitly given" do
      handler = described_class.new(Markbridge::AST::Spoiler, attribute: :spoiler, param: :title)

      handler.process(element: build_element('<SPOILER spoiler="surprise"/>'), parent:)

      expect(parent.children[0].title).to eq("surprise")
    end

    it "passes nil when the attribute is missing" do
      handler = described_class.new(Markbridge::AST::Color, attribute: :color)

      handler.process(element: build_element("<COLOR/>"), parent:)

      expect(parent.children[0].color).to be_nil
    end

    it "normalizes uppercase XML attribute names to lowercase symbol keys" do
      handler = described_class.new(Markbridge::AST::Color, attribute: :color)

      handler.process(element: build_element('<COLOR COLOR="red"/>'), parent:)

      expect(parent.children[0].color).to eq("red")
    end
  end

  describe "#element_class" do
    it "returns the configured element class" do
      handler = described_class.new(Markbridge::AST::Color, attribute: :color)

      expect(handler.element_class).to eq(Markbridge::AST::Color)
    end
  end
end
