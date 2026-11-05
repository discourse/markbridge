# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ImageTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  # The tag returns tokens, the renderer writes them.
  def rendered(element)
    renderer.serialize(tag.render(element, interface), context)
  end

  describe "#render" do
    it "returns an image token with the attributes of the element" do
      element = Markbridge::AST::Image.new(src: "a.png", alt: "x", width: 10, height: 5)

      expect(tag.render(element, interface)).to eq(
        [
          Markbridge::Renderers::Discourse::Inline::Tokens.image(
            src: "a.png",
            alt: "x",
            width: 10,
            height: 5,
          ),
        ],
      )
    end

    it "wraps a destination with a space in angle brackets" do
      element = Markbridge::AST::Image.new(src: "my image.png")

      expect(rendered(element)).to eq("![](<my image.png>)")
    end

    it "puts the words of an alt text with line breaks on one line" do
      element = Markbridge::AST::Image.new(src: "a.png", alt: "first\n\n  second\nthird")

      expect(rendered(element)).to eq("![first second third](a.png)")
    end

    context "when the alt text ends in a part that Discourse reads as an option" do
      def render_alt(alt, **size)
        rendered(Markbridge::AST::Image.new(src: "a.png", alt:, **size))
      end

      it "puts an empty part after the alt text" do
        # Discourse would take `|800x600` for a size; the empty part stops it.
        expect(render_alt("screenshot|800x600")).to eq("![screenshot\\|800x600|](a.png)")
      end

      it "keeps the size it writes itself after the empty part" do
        expect(render_alt("screenshot|800x600", width: 100, height: 50)).to eq(
          "![screenshot\\|800x600||100x50](a.png)",
        )
      end

      it "recognizes every kind of option" do
        [
          "10x20",
          "10x20, 50%",
          "10x20,x30",
          "10x20,50",
          "10x20 , 7x",
          "video",
          "audio",
          "thumbnail",
          "key=value",
          "data-x.y:z_1=a b",
          "=",
        ].each { |option| expect(render_alt("a|#{option}")).to end_with("|](a.png)"), option }
      end

      it "looks only at the last part" do
        expect(render_alt("10x20|a")).to eq("![10x20\\|a](a.png)")
      end
    end

    it "adds no empty part when the last part of the alt text is no option" do
      %w[a|b a|0x10 a|10x a|10x20,5000 a|10x20,0 a|Video a|x\ y=1 a|10x20x a| a].each do |alt|
        element = Markbridge::AST::Image.new(src: "a.png", alt:)

        expect(rendered(element)).to eq("![#{alt.gsub("|", "\\|")}](a.png)"), alt
      end
    end

    it "keeps an alt text that is nothing but an option" do
      # Discourse never takes the first part for an option.
      element = Markbridge::AST::Image.new(src: "a.png", alt: "800x600", width: 5)

      expect(rendered(element)).to eq("![800x600|5](a.png)")
    end

    it "renders image with src only" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png")

      result = rendered(element)
      expect(result).to eq("![](https://example.com/image.png)")
    end

    it "renders the alt text as the image description" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png", alt: "a cat")

      expect(rendered(element)).to eq("![a cat](https://example.com/image.png)")
    end

    it "escapes parentheses in the image destination" do
      opening = Markbridge::AST::Image.new(src: "https://example.com/a(b.png", alt: "opening")
      closing = Markbridge::AST::Image.new(src: "https://example.com/a)b.png", alt: "closing")

      expect(rendered(opening)).to eq("![opening](https://example.com/a\\(b.png)")
      expect(rendered(closing)).to eq("![closing](https://example.com/a\\)b.png)")
    end

    it "doubles a backslash in the image destination" do
      trailing = Markbridge::AST::Image.new(src: "https://example.com/a\\", alt: "trailing")
      before_paren = Markbridge::AST::Image.new(src: "https://example.com/a\\)b.png", alt: "paren")

      expect(rendered(trailing)).to eq("![trailing](https://example.com/a\\\\)")
      expect(rendered(before_paren)).to eq("![paren](https://example.com/a\\\\\\)b.png)")
    end

    it "puts the alt text in front of the dimensions" do
      element =
        Markbridge::AST::Image.new(
          src: "https://example.com/image.png",
          width: 100,
          height: 200,
          alt: "a cat",
        )

      expect(rendered(element)).to eq("![a cat|100x200](https://example.com/image.png)")
    end

    it "escapes the alt text like a link label" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png", alt: "a [cat] *")

      expect(rendered(element)).to eq("![a \\[cat\\] \\*](https://example.com/image.png)")
    end

    it "renders an empty alt text like a missing one" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png", alt: "")

      expect(rendered(element)).to eq("![](https://example.com/image.png)")
    end

    it "renders image with src and width" do
      element = Markbridge::AST::Image.new(src: "https://example.com/image.png", width: 100)

      result = rendered(element)
      expect(result).to eq("![|100](https://example.com/image.png)")
    end

    it "renders image with src, width, and height" do
      element =
        Markbridge::AST::Image.new(src: "https://example.com/image.png", width: 100, height: 200)

      result = rendered(element)
      expect(result).to eq("![|100x200](https://example.com/image.png)")
    end

    it "renders image with empty src when src is nil" do
      element = Markbridge::AST::Image.new

      result = rendered(element)
      expect(result).to eq("![]()")
    end

    it "renders image with width and height when src is empty" do
      element = Markbridge::AST::Image.new(src: "", width: 150, height: 250)

      result = rendered(element)
      expect(result).to eq("![|150x250]()")
    end

    it "renders without dimensions when only height is provided (height alone is meaningless)" do
      element = Markbridge::AST::Image.new(src: "x.png", height: 200)

      expect(rendered(element)).to eq("![](x.png)")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders <img> with src and empty alt" do
        element = Markbridge::AST::Image.new(src: "https://example.com/image.png")

        expect(rendered(element)).to eq(%(<img src="https://example.com/image.png" alt="">))
      end

      it "includes width and height when given" do
        element =
          Markbridge::AST::Image.new(src: "https://example.com/image.png", width: 100, height: 200)

        expect(rendered(element)).to eq(
          %(<img src="https://example.com/image.png" alt="" width="100" height="200">),
        )
      end

      it "attribute-escapes the alt text" do
        element = Markbridge::AST::Image.new(src: "x.png", alt: %(a "cat" <b>))

        expect(rendered(element)).to eq(%(<img src="x.png" alt="a &quot;cat&quot; &lt;b&gt;">))
      end

      it "attribute-escapes the src" do
        element = Markbridge::AST::Image.new(src: %(x"><script>alert(1)</script>))

        expect(rendered(element)).to eq(
          %(<img src="x&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;" alt="">),
        )
      end
    end
  end
end
