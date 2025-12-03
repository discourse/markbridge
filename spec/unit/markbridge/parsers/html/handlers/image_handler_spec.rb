# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::ImageHandler do
  let(:parent) { Markbridge::AST::Document.new }

  describe "#process" do
    it "creates an Image element with src" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": "image.png")
      allow(node).to receive(:[]).with("src").and_return("image.png")
      allow(node).to receive(:[]).with("width").and_return(nil)
      allow(node).to receive(:[]).with("height").and_return(nil)

      handler.process(element: node, parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Image)
      expect(parent.children[0].src).to eq("image.png")
    end

    it "extracts width and height attributes" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": nil)
      allow(node).to receive(:[]).with("src").and_return("image.png")
      allow(node).to receive(:[]).with("width").and_return("100")
      allow(node).to receive(:[]).with("height").and_return("200")

      handler.process(element: node, parent:)

      image = parent.children[0]
      expect(image.width).to eq(100)
      expect(image.height).to eq(200)
    end

    it "handles missing width and height" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": nil)
      allow(node).to receive(:[]).with("src").and_return("image.png")
      allow(node).to receive(:[]).with("width").and_return(nil)
      allow(node).to receive(:[]).with("height").and_return(nil)

      handler.process(element: node, parent:)

      image = parent.children[0]
      expect(image.width).to be_nil
      expect(image.height).to be_nil
    end

    it "sanitizes invalid dimensions" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": nil)
      allow(node).to receive(:[]).with("src").and_return("image.png")
      allow(node).to receive(:[]).with("width").and_return("-100")
      allow(node).to receive(:[]).with("height").and_return("0")

      handler.process(element: node, parent:)

      image = parent.children[0]
      expect(image.width).to be_nil
      expect(image.height).to be_nil
    end

    it "converts string dimensions to integers" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": nil)
      allow(node).to receive(:[]).with("src").and_return("image.png")
      allow(node).to receive(:[]).with("width").and_return("100")
      allow(node).to receive(:[]).with("height").and_return("200")

      handler.process(element: node, parent:)

      image = parent.children[0]
      expect(image.width).to be_a(Integer)
      expect(image.height).to be_a(Integer)
    end

    it "returns nil to signal no child processing needed" do
      handler = described_class.new
      node = instance_double(Nokogiri::XML::Element, "[]": nil)
      allow(node).to receive(:[]).with("src").and_return("image.png")
      allow(node).to receive(:[]).with("width").and_return(nil)
      allow(node).to receive(:[]).with("height").and_return(nil)

      result = handler.process(element: node, parent:)

      expect(result).to be_nil
    end
  end

  describe "#element_class" do
    it "returns AST::Image" do
      handler = described_class.new

      expect(handler.element_class).to eq(Markbridge::AST::Image)
    end
  end
end
