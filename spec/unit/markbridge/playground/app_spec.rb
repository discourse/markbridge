# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../playground/app"

RSpec.describe Markbridge::Playground::App do
  subject(:app) { described_class.allocate }

  describe "#convert" do
    it "renders BBCode to markdown and exposes the AST" do
      result = app.send(:convert, format: "bbcode", input: "[b]Hello[/b]")

      expect(result.fetch(:markdown)).to eq("**Hello**")
      expect(result.fetch(:ast)).to include("Document")
      expect(result.fetch(:ast)).to include("Bold")
      expect(result.fetch(:ast_json).fetch(:type)).to eq("Document")
      expect(result.fetch(:stats).fetch(:node_count)).to eq(3)
      expect(result.fetch(:unknown_tags)).to eq([])
    end

    it "raises for an unsupported format" do
      expect { app.send(:convert, format: "wat", input: "") }.to raise_error(
        ArgumentError,
        /unsupported format/,
      )
    end

    it "converts every bundled example without raising" do
      Markbridge::Playground::Examples.catalog.each do |example|
        result = app.send(:convert, format: example.fetch(:format), input: example.fetch(:input))

        expect(result.fetch(:ast)).to include("Document")
        expect(result.fetch(:markdown)).to be_a(String)
      end
    end
  end
end
