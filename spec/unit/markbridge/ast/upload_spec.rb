# frozen_string_literal: true

RSpec.describe Markbridge::AST::Upload do
  it "is a Node" do
    upload = described_class.new(sha1: "abc123")

    expect(upload).to be_a(Markbridge::AST::Node)
  end

  it "requires sha1" do
    upload = described_class.new(sha1: "RBhXLF6381Te3mneJQNnnyNNt5")

    expect(upload.sha1).to eq("RBhXLF6381Te3mneJQNnnyNNt5")
  end

  it "defaults type to :image" do
    upload = described_class.new(sha1: "abc123")

    expect(upload.type).to eq(:image)
  end

  it "has nil defaults for optional attributes" do
    upload = described_class.new(sha1: "abc123")

    expect(upload.filename).to be_nil
    expect(upload.alt).to be_nil
    expect(upload.dimensions).to be_nil
    expect(upload.size).to be_nil
    expect(upload.raw).to be_nil
  end

  it "stores image attributes" do
    upload =
      described_class.new(
        sha1: "RBhXLF6381Te3mneJQNnnyNNt5",
        filename: "image.png",
        type: :image,
        alt: "My image",
        dimensions: "64x64",
        raw: "![alt](upload://...)",
      )

    expect(upload.sha1).to eq("RBhXLF6381Te3mneJQNnnyNNt5")
    expect(upload.filename).to eq("image.png")
    expect(upload.type).to eq(:image)
    expect(upload.alt).to eq("My image")
    expect(upload.dimensions).to eq("64x64")
    expect(upload.raw).to eq("![alt](upload://...)")
  end

  it "stores attachment attributes" do
    upload =
      described_class.new(
        sha1: "ppJp89TTiLOo6Vl4mAmo21MV28w",
        filename: "document.pdf",
        type: :attachment,
        size: "502.1 KB",
      )

    expect(upload.sha1).to eq("ppJp89TTiLOo6Vl4mAmo21MV28w")
    expect(upload.filename).to eq("document.pdf")
    expect(upload.type).to eq(:attachment)
    expect(upload.size).to eq("502.1 KB")
  end
end
