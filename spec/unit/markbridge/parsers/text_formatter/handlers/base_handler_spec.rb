# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::BaseHandler do
  let(:exposed_handler_class) { Class.new(described_class) { public :extract_attributes } }
  let(:handler) { exposed_handler_class.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "raises NotImplementedError naming the subclass and the missing method" do
      expect { handler.process(element: build_element("<X/>"), parent: nil) }.to raise_error(
        NotImplementedError,
        "#{exposed_handler_class} must implement #process",
      )
    end
  end

  describe "#element_class" do
    it "raises NotImplementedError naming the subclass and the missing method" do
      expect { handler.element_class }.to raise_error(
        NotImplementedError,
        "#{exposed_handler_class} must implement #element_class",
      )
    end
  end

  describe "#extract_attributes" do
    it "returns attributes keyed by lowercased symbol" do
      element = build_element('<X Foo="1" BAR="two"/>')

      expect(handler.extract_attributes(element)).to eq(foo: "1", bar: "two")
    end

    it "returns an empty hash for elements with no attributes" do
      expect(handler.extract_attributes(build_element("<X/>"))).to eq({})
    end
  end
end
