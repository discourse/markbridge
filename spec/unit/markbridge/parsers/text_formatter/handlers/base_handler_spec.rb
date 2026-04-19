# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::TextFormatter::Handlers::BaseHandler do
  let(:handler) { described_class.new }

  def build_element(xml)
    Nokogiri::XML.fragment(xml).children.first
  end

  describe "#process" do
    it "raises NotImplementedError naming the subclass and the missing method" do
      subclass = Class.new(described_class)

      expect { subclass.new.process(element: build_element("<X/>"), parent: nil) }.to raise_error(
        NotImplementedError,
        "#{subclass} must implement #process",
      )
    end
  end

  describe "#element_class" do
    it "raises NotImplementedError naming the subclass and the missing method" do
      subclass = Class.new(described_class)

      expect { subclass.new.element_class }.to raise_error(
        NotImplementedError,
        "#{subclass} must implement #element_class",
      )
    end
  end

  # `#extract_attributes` is private. Coverage is exercised through any concrete
  # handler's `#process`, which calls it. Mutant test selection is pinned via
  # `mutant_expression:` on the concrete handler specs (see e.g.
  # spec/unit/markbridge/parsers/text_formatter/handlers/attachment_handler_spec.rb).
end
