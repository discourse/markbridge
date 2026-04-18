# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::RawHandler do
  let(:handler) { described_class.new(Markbridge::AST::Code) }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "creates an element of the configured class carrying the inner text" do
      handler.process(element: build_element("<code>code content</code>"), parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Code)
      expect(parent.children[0].children[0].text).to eq("code content")
    end

    it "extracts language from the class attribute" do
      handler.process(element: build_element('<code class="ruby">code</code>'), parent:)

      expect(parent.children[0].language).to eq("ruby")
    end

    it "extracts language from the lang attribute when class is missing" do
      handler.process(element: build_element('<code lang="python">code</code>'), parent:)

      expect(parent.children[0].language).to eq("python")
    end

    it "prefers the class attribute over lang when both are present" do
      handler.process(
        element: build_element('<code class="ruby" lang="python">code</code>'),
        parent:,
      )

      expect(parent.children[0].language).to eq("ruby")
    end

    it "leaves language nil when neither attribute is present" do
      handler.process(element: build_element("<code>code</code>"), parent:)

      expect(parent.children[0].language).to be_nil
    end

    it "does not append a Text child when the inner text is empty" do
      handler.process(element: build_element("<code></code>"), parent:)

      expect(parent.children[0].children).to be_empty
    end

    it "preserves whitespace in the inner text" do
      handler.process(element: build_element("<code>  line 1\n  line 2  </code>"), parent:)

      expect(parent.children[0].children[0].text).to eq("  line 1\n  line 2  ")
    end

    it "returns nil to signal children should not be processed" do
      result = handler.process(element: build_element("<code>code</code>"), parent:)

      expect(result).to be_nil
    end
  end

  describe "#element_class" do
    it "returns the element class it was initialized with" do
      expect(handler.element_class).to eq(Markbridge::AST::Code)
    end
  end
end
