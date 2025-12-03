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
end
