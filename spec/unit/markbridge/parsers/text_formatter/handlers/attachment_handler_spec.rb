# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::AttachmentHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "populates Attachment fields from XML attributes" do
      xml = '<ATTACHMENT id="abc" index="2" filename="photo.jpg" alt="photo"/>'

      result = handler.process(element: build_element(xml), parent:)

      attachment = parent.children[0]
      expect(attachment).to be_a(Markbridge::AST::Attachment)
      expect(attachment.id).to eq("abc")
      expect(attachment.index).to eq("2")
      expect(attachment.filename).to eq("photo.jpg")
      expect(attachment.alt).to eq("photo")
      expect(result).to eq(attachment)
    end

    it "leaves all fields nil when no attributes are present" do
      handler.process(element: build_element("<ATTACHMENT/>"), parent:)

      attachment = parent.children[0]
      expect(attachment.id).to be_nil
      expect(attachment.index).to be_nil
      expect(attachment.filename).to be_nil
      expect(attachment.alt).to be_nil
    end

    it "normalizes uppercase attribute names to lowercase symbol keys",
       mutant_expression: %w[
         Markbridge::Parsers::TextFormatter::Handlers::AttachmentHandler#process
         Markbridge::Parsers::TextFormatter::Handlers::BaseHandler#extract_attributes
       ] do
      handler.process(element: build_element('<ATTACHMENT ID="X" FILENAME="f"/>'), parent:)

      expect(parent.children[0].id).to eq("X")
      expect(parent.children[0].filename).to eq("f")
    end
  end

  describe "#element_class" do
    it "returns AST::Attachment" do
      expect(handler.element_class).to eq(Markbridge::AST::Attachment)
    end
  end
end
