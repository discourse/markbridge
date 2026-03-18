# frozen_string_literal: true

RSpec.describe Markbridge::AST::Event do
  it "is a Node" do
    event = described_class.new(name: "Meeting", starts_at: "2025-12-15 14:00")

    expect(event).to be_a(Markbridge::AST::Node)
  end

  it "requires name and start" do
    event = described_class.new(name: "Meeting", starts_at: "2025-12-15 14:00")

    expect(event.name).to eq("Meeting")
    expect(event.starts_at).to eq("2025-12-15 14:00")
  end

  it "has nil defaults for optional attributes" do
    event = described_class.new(name: "Meeting", starts_at: "2025-12-15 14:00")

    expect(event.ends_at).to be_nil
    expect(event.status).to be_nil
    expect(event.timezone).to be_nil
    expect(event.raw).to be_nil
  end

  it "stores all attributes" do
    event =
      described_class.new(
        name: "Conference",
        starts_at: "2025-12-15 09:00",
        ends_at: "2025-12-15 17:00",
        status: "public",
        timezone: "Europe/Vienna",
        raw: "[event]...[/event]",
      )

    expect(event.name).to eq("Conference")
    expect(event.starts_at).to eq("2025-12-15 09:00")
    expect(event.ends_at).to eq("2025-12-15 17:00")
    expect(event.status).to eq("public")
    expect(event.timezone).to eq("Europe/Vienna")
    expect(event.raw).to eq("[event]...[/event]")
  end
end
