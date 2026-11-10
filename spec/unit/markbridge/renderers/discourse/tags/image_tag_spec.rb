# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::ImageTag do
  include_context "with a renderer tag"

  # The serializer writes the image and its spec has the forms; these
  # examples check what the tag hands over.
  describe "#render" do
    it "makes the src absolute with a base URL" do
      base_url = Markbridge::Renderers::Discourse::BaseUrl.new("https://example.com/forum/")
      tag = described_class.new(base_url:)
      element = Markbridge::AST::Image.new(src: "/files/a.png", alt: "x")

      expect(tag.render(element, interface)).to eq(
        [
          Markbridge::Renderers::Discourse::Inline::Tokens.image(
            src: "https://example.com/files/a.png",
            alt: "x",
            width: nil,
            height: nil,
          ),
        ],
      )
    end

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
      element = Markbridge::AST::Image.new(src: "a.png", alt: "800x600", width: 5, height: 4)

      expect(rendered(element)).to eq("![800x600|5x4](a.png)")
    end

    it "doubles a backslash in the image destination" do
      trailing = Markbridge::AST::Image.new(src: "https://example.com/a\\", alt: "trailing")
      before_paren = Markbridge::AST::Image.new(src: "https://example.com/a\\)b.png", alt: "paren")

      expect(rendered(trailing)).to eq("![trailing](https://example.com/a\\\\)")
      expect(rendered(before_paren)).to eq("![paren](https://example.com/a\\\\\\)b.png)")
    end

    it "renders an image without a src to an empty destination" do
      expect(rendered(Markbridge::AST::Image.new)).to eq("![]()")
    end

    context "in html_mode" do
      let(:context) { html_context }

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
