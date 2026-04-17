# frozen_string_literal: true

RSpec.describe Markbridge::GemLoader do
  describe ".require_gem" do
    it "requires a gem that exists" do
      expect { described_class.require_gem("json", feature: "JSON parsing") }.not_to raise_error
    end

    it "accepts a symbol gem name" do
      expect { described_class.require_gem(:json, feature: "JSON parsing") }.not_to raise_error
    end

    it "raises LoadError with a helpful message when the gem is missing" do
      expect {
        described_class.require_gem("nope_does_not_exist_gem", feature: "fancy parsing")
      }.to raise_error(
        LoadError,
        "Nope_does_not_exist_gem is required for fancy parsing. " \
          "Add 'gem \"nope_does_not_exist_gem\"' to your Gemfile or " \
          "install it with 'gem install nope_does_not_exist_gem'.",
      )
    end

    it "uses the symbol name in the error message when given a symbol" do
      expect { described_class.require_gem(:nope_missing_sym, feature: "X") }.to raise_error(
        LoadError,
      ) { |error|
        expect(error.message).to match(/\ANope_missing_sym/)
        expect(error.message).to include('gem "nope_missing_sym"')
        expect(error.message).to include("gem install nope_missing_sym")
      }
    end

    it "interpolates the feature description into the message" do
      expect {
        described_class.require_gem("missing_xyz", feature: "rendering colored text")
      }.to raise_error(LoadError, /required for rendering colored text\./)
    end
  end
end
