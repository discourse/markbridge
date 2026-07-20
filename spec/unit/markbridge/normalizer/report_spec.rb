# frozen_string_literal: true

RSpec.describe Markbridge::Normalizer::Report do
  subject(:report) { described_class.new }

  describe "#empty?" do
    it "is true for a fresh report" do
      expect(report.empty?).to be(true)
    end

    it "is false after a record" do
      report.record(Markbridge::AST::Url, Markbridge::AST::Image, :hoist_after)
      expect(report.empty?).to be(false)
    end
  end

  describe "#to_a" do
    it "is empty for a fresh report" do
      expect(report.to_a).to eq([])
    end

    it "returns one row per transformation with demodulized class names" do
      report.record(Markbridge::AST::Url, Markbridge::AST::Image, :hoist_after)
      expect(report.to_a).to eq(
        [{ parent: "Url", child: "Image", strategy: :hoist_after, count: 1 }],
      )
    end

    it "tallies repeats of the same transformation" do
      3.times { report.record(Markbridge::AST::Url, Markbridge::AST::Image, :hoist_after) }
      expect(report.to_a).to eq(
        [{ parent: "Url", child: "Image", strategy: :hoist_after, count: 3 }],
      )
    end

    it "keeps transformations that differ in parent or child as separate rows" do
      report.record(Markbridge::AST::Url, Markbridge::AST::Image, :hoist_after)
      report.record(Markbridge::AST::Url, Markbridge::AST::Url, :unwrap)
      expect(report.to_a).to contain_exactly(
        { parent: "Url", child: "Image", strategy: :hoist_after, count: 1 },
        { parent: "Url", child: "Url", strategy: :unwrap, count: 1 },
      )
    end

    it "distinguishes rows that differ only by strategy" do
      report.record(Markbridge::AST::Url, Markbridge::AST::Image, :hoist_after)
      report.record(Markbridge::AST::Url, Markbridge::AST::Image, :drop)
      expect(report.to_a.size).to eq(2)
    end
  end
end
