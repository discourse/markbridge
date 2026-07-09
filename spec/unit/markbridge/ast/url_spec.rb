# frozen_string_literal: true

RSpec.describe Markbridge::AST::Url do
  it "is an Element" do
    element = described_class.new
    expect(element).to be_a(Markbridge::AST::Element)
  end

  describe "#href" do
    it "returns nil by default" do
      element = described_class.new
      expect(element.href).to be_nil
    end

    it "returns the href when set" do
      element = described_class.new(href: "https://example.com")
      expect(element.href).to eq("https://example.com")
    end

    it "can be set to different URLs" do
      url1 = described_class.new(href: "https://example.com")
      url2 = described_class.new(href: "https://google.com")

      expect(url1.href).to eq("https://example.com")
      expect(url2.href).to eq("https://google.com")
    end
  end

  it "can have children" do
    element = described_class.new(href: "https://example.com")
    text = Markbridge::AST::Text.new("link text")
    element << text

    expect(element.children).to eq([text])
  end

  describe "#bare?" do
    it "is bare with no children" do
      expect(described_class.new(href: "https://example.com").bare?).to be true
    end

    it "is bare when the only child is a Text equal to the href" do
      element = described_class.new(href: "https://example.com")
      element << Markbridge::AST::Text.new("https://example.com")

      expect(element.bare?).to be true
    end

    it "is not bare when the text differs from the href" do
      element = described_class.new(href: "https://example.com")
      element << Markbridge::AST::Text.new("click here")

      expect(element.bare?).to be false
    end

    it "is not bare when more children follow the href-equal text" do
      element = described_class.new(href: "https://example.com")
      element << Markbridge::AST::Text.new("https://example.com")
      element << Markbridge::AST::Bold.new

      expect(element.bare?).to be false
    end

    it "is not bare when the only child is a non-Text node" do
      element = described_class.new(href: "https://example.com")
      element << Markbridge::AST::Bold.new

      expect(element.bare?).to be false
    end
  end
end
