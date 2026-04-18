# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::CodeHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "extracts language from the lang attribute" do
      result = handler.process(element: build_element('<CODE lang="ruby"/>'), parent:)

      expect(parent.children[0]).to be_a(Markbridge::AST::Code)
      expect(parent.children[0].language).to eq("ruby")
      expect(result).to eq(parent.children[0])
    end

    it "falls back to the language attribute when lang is absent" do
      handler.process(element: build_element('<CODE language="python"/>'), parent:)

      expect(parent.children[0].language).to eq("python")
    end

    it "prefers lang over language when both are present" do
      handler.process(element: build_element('<CODE lang="ruby" language="python"/>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "leaves language nil when neither attribute is present" do
      handler.process(element: build_element("<CODE/>"), parent:)

      expect(parent.children[0].language).to be_nil
    end

    it "normalizes uppercase XML attribute names to lowercase symbol keys" do
      handler.process(element: build_element('<CODE LANG="ruby"/>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end
  end

  describe "#element_class" do
    it "returns AST::Code" do
      expect(handler.element_class).to eq(Markbridge::AST::Code)
    end
  end
end
