# frozen_string_literal: true

RSpec.describe Markbridge::Parsers::BBCode::Handlers::CodeHandler do
  describe "#initialize" do
    it "exposes AST::Code as the element_class" do
      expect(described_class.new.element_class).to eq(Markbridge::AST::Code)
    end

    it "is a RawHandler subclass (body content isn't re-parsed as BBCode)" do
      expect(described_class.new).to be_a(Markbridge::Parsers::BBCode::Handlers::RawHandler)
    end
  end
end
