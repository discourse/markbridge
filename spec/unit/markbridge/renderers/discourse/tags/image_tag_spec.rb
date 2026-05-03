# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ImageTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders image with src only" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png")

      result = tag.render(element, interface)
      expect(result).to eq("![](https://example.com/image.png)")
    end

    it "renders image with src and width" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png", width: 100)

      result = tag.render(element, interface)
      expect(result).to eq("![|100](https://example.com/image.png)")
    end

    it "renders image with src, width, and height" do
      element =
        Markbridge::AST::Image.new(src: "https://example.com/image.png", width: 100, height: 200)

      result = tag.render(element, interface)
      expect(result).to eq("![|100x200](https://example.com/image.png)")
    end

    it "renders image with empty src when src is nil" do
      element = Markbridge::AST::Image.new

      result = tag.render(element, interface)
      expect(result).to eq("![]()")
    end

    it "renders image with width and height when src is empty" do
      element = Markbridge::AST::Image.new(src: "", width: 150, height: 250)

      result = tag.render(element, interface)
      expect(result).to eq("![|150x250]()")
    end

    it "renders without dimensions when only height is provided (height alone is meaningless)" do
      element = Markbridge::AST::Image.new(src: "x.png", height: 200)

      expect(tag.render(element, interface)).to eq("![](x.png)")
    end
  end
end
