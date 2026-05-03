# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::ImageHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "creates an Image with src, width, and height from attributes" do
      result =
        handler.process(
          element: build_element('<IMG src="x.png" width="100" height="200"/>'),
          parent:,
        )

      image = parent.children[0]
      expect(image).to be_a(Markbridge::AST::Image)
      expect(image.src).to eq("x.png")
      expect(image.width).to eq(100)
      expect(image.height).to eq(200)
      expect(result).to eq(image)
    end

    it "converts the width attribute to an integer" do
      handler.process(element: build_element('<IMG src="x.png" width="150"/>'), parent:)

      expect(parent.children[0].width).to eq(150)
      expect(parent.children[0].width).to be_a(Integer)
    end

    it "converts the height attribute to an integer" do
      handler.process(element: build_element('<IMG src="x.png" height="250"/>'), parent:)

      expect(parent.children[0].height).to eq(250)
      expect(parent.children[0].height).to be_a(Integer)
    end

    it "leaves width and height nil when absent (no coercion of missing)" do
      handler.process(element: build_element('<IMG src="x.png"/>'), parent:)

      expect(parent.children[0].width).to be_nil
      expect(parent.children[0].height).to be_nil
    end

    it "leaves src nil when absent" do
      handler.process(element: build_element("<IMG/>"), parent:)

      expect(parent.children[0].src).to be_nil
    end

    it "normalizes uppercase XML attribute names to lowercase symbol keys" do
      handler.process(element: build_element('<IMG SRC="x.png" WIDTH="100"/>'), parent:)

      expect(parent.children[0].src).to eq("x.png")
      expect(parent.children[0].width).to eq(100)
    end
  end

  describe "#element_class" do
    it "returns AST::Image" do
      expect(handler.element_class).to eq(Markbridge::AST::Image)
    end
  end
end
