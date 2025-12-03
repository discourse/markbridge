# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::RawHandler do
  let(:parent) { Markbridge::AST::Document.new }

  describe "#process" do
    it "creates a Code element with inner text" do
      handler = described_class.new(Markbridge::AST::Code)
      node = instance_double(Nokogiri::XML::Element, "[]": nil, inner_text: "code content")

      handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Code)
      expect(parent.children[0].children[0].text).to eq("code content")
    end

    it "extracts language from class attribute" do
      handler = described_class.new(Markbridge::AST::Code)
      node = instance_double(Nokogiri::XML::Element, "[]": "ruby", inner_text: "code")
      allow(node).to receive(:[]).with("class").and_return("ruby")
      allow(node).to receive(:[]).with("lang").and_return(nil)

      handler.process(element: node, parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "extracts language from lang attribute" do
      handler = described_class.new(Markbridge::AST::Code)
      node = instance_double(Nokogiri::XML::Element, "[]": "python", inner_text: "code")
      allow(node).to receive(:[]).with("class").and_return(nil)
      allow(node).to receive(:[]).with("lang").and_return("python")

      handler.process(element: node, parent:)

      expect(parent.children[0].language).to eq("python")
    end

    it "prefers class over lang attribute" do
      handler = described_class.new(Markbridge::AST::Code)
      node = instance_double(Nokogiri::XML::Element, "[]": "ruby", inner_text: "code")
      allow(node).to receive(:[]).with("class").and_return("ruby")
      allow(node).to receive(:[]).with("lang").and_return("python")

      handler.process(element: node, parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "handles empty content" do
      handler = described_class.new(Markbridge::AST::Code)
      node = instance_double(Nokogiri::XML::Element, "[]": nil, inner_text: "")

      handler.process(element: node, parent:)

      expect(parent.children[0].children).to be_empty
    end

    it "preserves whitespace in content" do
      handler = described_class.new(Markbridge::AST::Code)
      content = "  line 1\n  line 2  "
      node = instance_double(Nokogiri::XML::Element, "[]": nil, inner_text: content)

      handler.process(element: node, parent:)

      expect(parent.children[0].children[0].text).to eq(content)
    end

    it "returns nil to signal no child processing needed" do
      handler = described_class.new(Markbridge::AST::Code)
      node = instance_double(Nokogiri::XML::Element, "[]": nil, inner_text: "code")

      result = handler.process(element: node, parent:)

      expect(result).to be_nil
    end
  end

  describe "#element_class" do
    it "returns the element class" do
      handler = described_class.new(Markbridge::AST::Code)

      expect(handler.element_class).to eq(Markbridge::AST::Code)
    end
  end
end
