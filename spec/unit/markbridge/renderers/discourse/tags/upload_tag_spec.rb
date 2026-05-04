# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::UploadTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "returns the raw markdown verbatim when present" do
      element = Markbridge::AST::Upload.new(sha1: "abc", raw: "![](upload://original.png)")

      expect(tag.render(element, interface)).to eq("![](upload://original.png)")
    end

    it "renders an image upload as ![alt](upload://filename) when type is image" do
      element =
        Markbridge::AST::Upload.new(
          sha1: "abc",
          filename: "pic.png",
          type: :image,
          alt: "A picture",
          dimensions: "100x200",
        )

      expect(tag.render(element, interface)).to eq("![A picture|100x200](upload://pic.png)")
    end

    it "uses sha1 as URL filename when filename is missing" do
      element = Markbridge::AST::Upload.new(sha1: "abc123", type: :image)

      expect(tag.render(element, interface)).to eq("![](upload://abc123)")
    end

    it "omits dimensions from alt when only alt is set" do
      element = Markbridge::AST::Upload.new(sha1: "x", type: :image, alt: "just alt")

      expect(tag.render(element, interface)).to eq("![just alt](upload://x)")
    end

    it "omits alt from alt-text when only dimensions are set" do
      element = Markbridge::AST::Upload.new(sha1: "x", type: :image, dimensions: "10x10")

      expect(tag.render(element, interface)).to eq("![10x10](upload://x)")
    end

    it "renders an attachment upload as [filename|attachment](upload://filename)" do
      element = Markbridge::AST::Upload.new(sha1: "abc", filename: "doc.pdf", type: :attachment)

      expect(tag.render(element, interface)).to eq("[doc.pdf|attachment](upload://doc.pdf)")
    end

    it "appends size in parentheses when present on attachments" do
      element =
        Markbridge::AST::Upload.new(
          sha1: "abc",
          filename: "doc.pdf",
          type: :attachment,
          size: "1.2 MB",
        )

      expect(tag.render(element, interface)).to eq(
        "[doc.pdf|attachment](upload://doc.pdf) (1.2 MB)",
      )
    end

    it "uses 'attachment' as filename fallback when missing" do
      element = Markbridge::AST::Upload.new(sha1: "abc123", type: :attachment)

      expect(tag.render(element, interface)).to eq("[attachment|attachment](upload://abc123)")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "renders an image upload as <img> with upload:// src and alt text" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "pic.png",
            type: :image,
            alt: "A picture",
          )

        expect(tag.render(element, interface)).to eq(
          %(<img src="upload://pic.png" alt="A picture">),
        )
      end

      it "uses sha1 as URL filename and empty alt when both are missing" do
        element = Markbridge::AST::Upload.new(sha1: "abc123", type: :image)

        expect(tag.render(element, interface)).to eq(%(<img src="upload://abc123" alt="">))
      end

      it "HTML-escapes alt and src so the output is safe to splice into raw HTML" do
        element =
          Markbridge::AST::Upload.new(sha1: "abc", filename: %(bad"&.png), type: :image, alt: "<x>")

        expect(tag.render(element, interface)).to eq(
          %(<img src="upload://bad&quot;&amp;.png" alt="&lt;x&gt;">),
        )
      end

      it "renders an attachment upload as <a href> with filename as link text" do
        element = Markbridge::AST::Upload.new(sha1: "abc", filename: "doc.pdf", type: :attachment)

        expect(tag.render(element, interface)).to eq(%(<a href="upload://doc.pdf">doc.pdf</a>))
      end

      it "appends the size in parentheses after attachment links" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "doc.pdf",
            type: :attachment,
            size: "1.2 MB",
          )

        expect(tag.render(element, interface)).to eq(
          %(<a href="upload://doc.pdf">doc.pdf</a> (1.2 MB)),
        )
      end

      it "uses 'attachment' as filename fallback for attachment links" do
        element = Markbridge::AST::Upload.new(sha1: "abc123", type: :attachment)

        expect(tag.render(element, interface)).to eq(%(<a href="upload://abc123">attachment</a>))
      end

      it "HTML-escapes attachment href, filename label, and size" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: %(weird"&.pdf),
            type: :attachment,
            size: %(1.2 MB " <evil>),
          )

        expect(tag.render(element, interface)).to eq(
          %(<a href="upload://weird&quot;&amp;.pdf">weird&quot;&amp;.pdf</a> ) +
            "(1.2 MB &quot; &lt;evil&gt;)",
        )
      end

      it "ignores element.raw and reconstructs HTML from the AST fields" do
        element =
          Markbridge::AST::Upload.new(
            sha1: "abc",
            filename: "pic.png",
            type: :image,
            raw: "![](upload://other.png)",
          )

        expect(tag.render(element, interface)).to eq(%(<img src="upload://pic.png" alt="">))
      end
    end
  end
end
