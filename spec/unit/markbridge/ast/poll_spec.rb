# frozen_string_literal: true

RSpec.describe Markbridge::AST::Poll do
  it "is a Node" do
    poll = described_class.new

    expect(poll).to be_a(Markbridge::AST::Node)
  end

  it "has sensible defaults" do
    poll = described_class.new

    expect(poll.name).to eq("poll")
    expect(poll.type).to be_nil
    expect(poll.results).to be_nil
    expect(poll.public).to be false
    expect(poll.chart_type).to be_nil
    expect(poll.options).to eq([])
    expect(poll.raw).to be_nil
  end

  it "stores all attributes" do
    poll =
      described_class.new(
        name: "favorite-color",
        type: "multiple",
        results: "on_vote",
        public: true,
        chart_type: "pie",
        options: %w[Red Blue Green],
        raw: "[poll]...[/poll]",
      )

    expect(poll.name).to eq("favorite-color")
    expect(poll.type).to eq("multiple")
    expect(poll.results).to eq("on_vote")
    expect(poll.public).to be true
    expect(poll.chart_type).to eq("pie")
    expect(poll.options).to eq(%w[Red Blue Green])
    expect(poll.raw).to eq("[poll]...[/poll]")
  end
end
