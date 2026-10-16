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

    it "renders the alt text as the image description" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png", alt: "a cat")

      expect(tag.render(element, interface)).to eq("![a cat](https://example.com/image.png)")
    end

    it "escapes parentheses in the image destination" do
      opening = Markbridge::AST::Image.new(src: "https://example.com/a(b.png", alt: "opening")
      closing = Markbridge::AST::Image.new(src: "https://example.com/a)b.png", alt: "closing")

      expect(tag.render(opening, interface)).to eq("![opening](https://example.com/a\\(b.png)")
      expect(tag.render(closing, interface)).to eq("![closing](https://example.com/a\\)b.png)")
    end

    it "doubles a backslash in the image destination" do
      trailing = Markbridge::AST::Image.new(src: "https://example.com/a\\", alt: "trailing")
      before_paren = Markbridge::AST::Image.new(src: "https://example.com/a\\)b.png", alt: "paren")

      expect(tag.render(trailing, interface)).to eq("![trailing](https://example.com/a\\\\)")
      expect(tag.render(before_paren, interface)).to eq(
        "![paren](https://example.com/a\\\\\\)b.png)",
      )
    end

    it "puts the alt text in front of the dimensions" do
      element =
        Markbridge::AST::Image.new(
          src: "https://example.com/image.png",
          width: 100,
          height: 200,
          alt: "a cat",
        )

      expect(tag.render(element, interface)).to eq(
        "![a cat|100x200](https://example.com/image.png)",
      )
    end

    it "escapes the alt text like a link label" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png", alt: "a [cat] *")

      expect(tag.render(element, interface)).to eq(
        "![a \\[cat\\] \\*](https://example.com/image.png)",
      )
    end

    it "renders an empty alt text like a missing one" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png", alt: "")

      expect(tag.render(element, interface)).to eq("![](https://example.com/image.png)")
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

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <img> with src and empty alt" do
        element = Markbridge::AST::Image.new(src: "https://example.com/image.png")

        expect(tag.render(element, interface)).to eq(
          %(<img src="https://example.com/image.png" alt="">),
        )
      end

      it "includes width and height when given" do
        element =
          Markbridge::AST::Image.new(src: "https://example.com/image.png", width: 100, height: 200)

        expect(tag.render(element, interface)).to eq(
          %(<img src="https://example.com/image.png" alt="" width="100" height="200">),
        )
      end

      it "attribute-escapes the alt text" do
        element = Markbridge::AST::Image.new(src: "x.png", alt: %(a "cat" <b>))

        expect(tag.render(element, interface)).to eq(
          %(<img src="x.png" alt="a &quot;cat&quot; &lt;b&gt;">),
        )
      end

      it "attribute-escapes the src" do
        element = Markbridge::AST::Image.new(src: %(x"><script>alert(1)</script>))

        expect(tag.render(element, interface)).to eq(
          %(<img src="x&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;" alt="">),
        )
      end
    end
  end
end
