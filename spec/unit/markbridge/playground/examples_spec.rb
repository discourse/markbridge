# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../playground/examples"

RSpec.describe Markbridge::Playground::Examples do
  describe ".catalog" do
    it "includes comprehensive examples for each supported input format" do
      catalog = described_class.catalog

      expect(catalog.map { |example| example.fetch(:format) }).to include(
        "bbcode",
        "html",
        "text_formatter",
      )
      expect(catalog).to all(include(:id, :format, :scenario, :description, :highlights, :input))
      expect(catalog).to all(satisfy { |example| !example.fetch(:input).empty? })
    end

    it "provides the core debugging scenarios for every format" do
      scenarios_by_format =
        described_class
          .catalog
          .group_by { |example| example.fetch(:format) }
          .transform_values { |examples| examples.map { |example| example.fetch(:scenario) } }

      %w[bbcode html text_formatter].each do |format|
        expect(scenarios_by_format.fetch(format)).to include(
          "coverage",
          "deep_nesting",
          "graceful_degradation",
          "markdown_escaper",
        )
      end
    end
  end
end
