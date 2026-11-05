# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::AttachmentTag do
  include_context "with a renderer tag"

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
      let(:context) { html_context }

      it "emits the same HTML comment so the renderer leaves it unwrapped" do
        element = Markbridge::AST::Attachment.new(id: "1234")

        expect(tag.render(element, interface)).to eq("<!-- ATTACHMENT: id=1234 -->")
      end
    end
  end
end
