# frozen_string_literal: true

RSpec.describe Markbridge::Configuration do
  subject(:configuration) { described_class.new }

  describe "#escape_hard_line_breaks" do
    it "defaults to false" do
      expect(configuration.escape_hard_line_breaks).to be false
    end

    it "can be set to true" do
      configuration.escape_hard_line_breaks = true
      expect(configuration.escape_hard_line_breaks).to be true
    end
  end
end
