# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::HeadingHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }

  def build_element(html)
    Nokogiri::HTML.fragment(html).children.first
  end

  describe "#process" do
    it "creates a Heading element and returns it so children get processed inside" do
      result = handler.process(element: build_element("<h1>Title</h1>"), parent:)

      expect(parent.children.size).to eq(1)
      expect(parent.children[0]).to be_a(Markbridge::AST::Heading)
      expect(result).to eq(parent.children[0])
    end

    (1..6).each do |level|
      it "maps <h#{level}> to a Heading with level #{level}" do
        result = handler.process(element: build_element("<h#{level}>Title</h#{level}>"), parent:)

        expect(result.level).to eq(level)
      end
    end

    # The handler itself accepts any element name — a consumer can register
    # it for other tags — so levels outside 1..6 must stay in range.
    it "clamps levels above 6 down to 6" do
      result = handler.process(element: build_element("<h7>Title</h7>"), parent:)

      expect(result.level).to eq(6)
    end

    it "uses level 1 when the tag name has no number" do
      # A made-up tag name a consumer might register; not to be confused
      # with the HTML5 <header> element, which stays out of the registry.
      result = handler.process(element: build_element("<heading>Title</heading>"), parent:)

      expect(result.level).to eq(1)
    end
  end

  describe "#element_class" do
    it "returns AST::Heading" do
      expect(handler.element_class).to eq(Markbridge::AST::Heading)
    end
  end
end
