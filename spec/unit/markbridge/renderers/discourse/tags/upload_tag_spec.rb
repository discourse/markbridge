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
  end
end
