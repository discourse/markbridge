# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::AttachmentTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "renders attachment with id only" do
      element = Markbridge::AST::Attachment.new(id: "1234")

      result = tag.render(element, interface)
      expect(result).to eq("<!-- ATTACHMENT: id=1234 -->")
    end

    it "renders attachment with index only" do
      element = Markbridge::AST::Attachment.new(index: "0")

      result = tag.render(element, interface)
      expect(result).to eq("<!-- ATTACHMENT: index=0 -->")
    end

    it "renders attachment with index and filename" do
      element = Markbridge::AST::Attachment.new(index: "2", filename: "image.jpg")

      result = tag.render(element, interface)
      expect(result).to eq("<!-- ATTACHMENT: index=2 filename=image.jpg -->")
    end

    it "renders attachment with id and alt" do
      element = Markbridge::AST::Attachment.new(id: "5678", alt: "diagram")

      result = tag.render(element, interface)
      expect(result).to eq("<!-- ATTACHMENT: id=5678 alt=diagram -->")
    end

    it "renders attachment with all metadata" do
      element =
        Markbridge::AST::Attachment.new(
          id: "1111",
          index: "3",
          filename: "file.jpg",
          alt: "custom alt",
        )

      result = tag.render(element, interface)
      expect(result).to eq("<!-- ATTACHMENT: id=1111 index=3 filename=file.jpg alt=custom alt -->")
    end

    it "renders attachment with no identifier" do
      element = Markbridge::AST::Attachment.new

      result = tag.render(element, interface)
      expect(result).to eq("<!-- ATTACHMENT: UNIDENTIFIED -->")
    end

    context "in html_mode" do
      let(:context) { Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true) }

      it "emits the same HTML comment so the renderer leaves it unwrapped" do
        element = Markbridge::AST::Attachment.new(id: "1234")

        expect(tag.render(element, interface)).to eq("<!-- ATTACHMENT: id=1234 -->")
      end
    end
  end

  describe "#html_mode_aware?" do
    it "returns true" do
      expect(described_class.new.html_mode_aware?).to be true
    end
  end
end
