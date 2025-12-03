# frozen_string_literal: true

RSpec.describe Markbridge::AST::Attachment do
  it "is a Node" do
    attachment = described_class.new

    expect(attachment).to be_a(Markbridge::AST::Node)
  end

  it "defaults to nil attributes" do
    attachment = described_class.new

    expect(attachment.id).to be_nil
    expect(attachment.index).to be_nil
    expect(attachment.filename).to be_nil
    expect(attachment.alt).to be_nil
  end

  it "stores metadata" do
    attachment = described_class.new(id: "1234", index: 3, filename: "image.jpg", alt: "diagram")

    expect(attachment.id).to eq("1234")
    expect(attachment.index).to eq(3)
    expect(attachment.filename).to eq("image.jpg")
    expect(attachment.alt).to eq("diagram")
  end
end
