# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::HTML::Handlers::BaseHandler do
  let(:handler) { described_class.new }
  let(:parent) { Markbridge::AST::Document.new }
  let(:element) { instance_double(Nokogiri::XML::Element) }

  describe "#process" do
    it "returns nil without mutating parent" do
      expect(handler.process(element:, parent:)).to be_nil
      expect(parent.children).to be_empty
    end
  end

  describe "#element_class" do
    it "is nil by default (subclasses expose via attr_reader)" do
      expect(handler.element_class).to be_nil
    end
  end
end
