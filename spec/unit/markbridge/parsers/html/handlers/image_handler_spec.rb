# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::ImageHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "creates an Image element with src from the src attribute" do
      handler.process(element: build_element('<img src="image.png">'), parent:)

      image = parent.children[0]
      expect(image).to be_a(Markbridge::AST::Image)
      expect(image.src).to eq("image.png")
      expect(image.width).to be_nil
      expect(image.height).to be_nil
    end

    it "extracts width and height attributes as integers" do
      handler.process(
        element: build_element('<img src="image.png" width="100" height="200">'),
        parent:,
      )

      image = parent.children[0]
      expect(image.width).to eq(100)
      expect(image.height).to eq(200)
    end

    it "leaves width nil when the attribute is missing but sets height from its attribute" do
      handler.process(element: build_element('<img src="image.png" height="200">'), parent:)

      image = parent.children[0]
      expect(image.width).to be_nil
      expect(image.height).to eq(200)
    end

    it "leaves height nil when the attribute is missing but sets width from its attribute" do
      handler.process(element: build_element('<img src="image.png" width="100">'), parent:)

      image = parent.children[0]
      expect(image.width).to eq(100)
      expect(image.height).to be_nil
    end

    it "drops negative width and zero height" do
      handler.process(
        element: build_element('<img src="image.png" width="-100" height="0">'),
        parent:,
      )

      image = parent.children[0]
      expect(image.width).to be_nil
      expect(image.height).to be_nil
    end

    it "drops non-numeric dimensions" do
      handler.process(
        element: build_element('<img src="image.png" width="auto" height="abc">'),
        parent:,
      )

      image = parent.children[0]
      expect(image.width).to be_nil
      expect(image.height).to be_nil
    end

    it "leaves src nil when the attribute is missing" do
      handler.process(element: build_element("<img>"), parent:)

      expect(parent.children[0].src).to be_nil
    end

    it "returns nil to signal children should not be processed" do
      result = handler.process(element: build_element('<img src="image.png">'), parent:)

      expect(result).to be_nil
    end
  end

  describe "#element_class" do
    it "returns AST::Image" do
      expect(handler.element_class).to eq(Markbridge::AST::Image)
    end
  end
end
