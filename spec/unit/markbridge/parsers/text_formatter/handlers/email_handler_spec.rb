# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::EmailHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "creates an Email node with the address pulled from the email attribute" do
      result = handler.process(element: build_element('<EMAIL email="a@b.c"/>'), parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::Email)
      expect(parent.children[0].address).to eq("a@b.c")
      expect(result).to eq(parent.children[0])
    end

    it "leaves address nil when the email attribute is absent" do
      handler.process(element: build_element("<EMAIL/>"), parent:)

      expect(parent.children[0].address).to be_nil
    end

    it "normalizes uppercase XML attribute names to lowercase symbol keys" do
      handler.process(element: build_element('<EMAIL EMAIL="a@b.c"/>'), parent:)

      expect(parent.children[0].address).to eq("a@b.c")
    end
  end

  describe "#element_class" do
    it "returns AST::Email" do
      expect(handler.element_class).to eq(Markbridge::AST::Email)
    end
  end
end
