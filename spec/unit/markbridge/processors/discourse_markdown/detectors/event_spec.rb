# frozen_string_literal: true

RSpec.describe Markbridge::Processors::DiscourseMarkdown::Detectors::Event do
  subject(:detector) { described_class.new }

  describe "#detect" do
    it "detects event with required attributes" do
      input = '[event name="Meeting" start="2025-12-15 14:00"][/event]'
      match = detector.detect(input, 0)

      expect(match).not_to be_nil
      expect(match.start_pos).to eq(0)
      expect(match.end_pos).to eq(input.length)
      expect(match.node).to be_a(Markbridge::AST::Event)
    end

    it "returns nil when not at [" do
      match = detector.detect('text [event name="x" start="y"][/event]', 0)

      expect(match).to be_nil
    end

    it "returns nil for non-event tag" do
      match = detector.detect("[poll][/poll]", 0)

      expect(match).to be_nil
    end

    it "returns nil when closing tag is missing" do
      input = '[event name="Meeting" start="2025-12-15"]'
      match = detector.detect(input, 0)

      expect(match).to be_nil
    end

    it "returns nil when name is missing" do
      input = '[event start="2025-12-15"][/event]'
      match = detector.detect(input, 0)

      expect(match).to be_nil
    end

    it "returns nil when start is missing" do
      input = '[event name="Meeting"][/event]'
      match = detector.detect(input, 0)

      expect(match).to be_nil
    end

    it "extracts name and start" do
      input = '[event name="Team Meeting" start="2025-12-15 14:00"][/event]'
      match = detector.detect(input, 0)

      expect(match.node.name).to eq("Team Meeting")
      expect(match.node.starts_at).to eq("2025-12-15 14:00")
    end

    it "extracts end time" do
      input = '[event name="Conf" start="2025-12-15" end="2025-12-16"][/event]'
      match = detector.detect(input, 0)

      expect(match.node.ends_at).to eq("2025-12-16")
    end

    it "extracts status" do
      input = '[event name="Conf" start="2025-12-15" status="public"][/event]'
      match = detector.detect(input, 0)

      expect(match.node.status).to eq("public")
    end

    it "extracts timezone" do
      input = '[event name="Conf" start="2025-12-15" timezone="Europe/Vienna"][/event]'
      match = detector.detect(input, 0)

      expect(match.node.timezone).to eq("Europe/Vienna")
    end

    it "stores raw BBCode" do
      input = '[event name="Meeting" start="2025-12-15"][/event]'
      match = detector.detect(input, 0)

      expect(match.node.raw).to eq(input)
    end

    it "handles single-quoted attributes" do
      input = "[event name='Meeting' start='2025-12-15'][/event]"
      match = detector.detect(input, 0)

      expect(match.node.name).to eq("Meeting")
    end

    it "is case-insensitive for tag name" do
      input = '[EVENT name="Meeting" start="2025-12-15"][/EVENT]'
      match = detector.detect(input, 0)

      expect(match).not_to be_nil
    end

    it "handles content between tags" do
      input = '[event name="Meeting" start="2025-12-15"]\nSome description\n[/event]'
      match = detector.detect(input, 0)

      expect(match).not_to be_nil
      expect(match.end_pos).to eq(input.length)
    end

    it "detects an event at a non-zero position" do
      input = 'prefix [event name="Meeting" start="2025-12-15"][/event] suffix'
      match = detector.detect(input, 7)

      expect(match).not_to be_nil
      expect(match.start_pos).to eq(7)
      expect(match.end_pos).to eq(input.length - " suffix".length)
      expect(match.node.name).to eq("Meeting")
      # raw must be exactly the event, not the surrounding input
      expect(match.node.raw).to eq('[event name="Meeting" start="2025-12-15"][/event]')
    end

    it "returns nil when pos points past the start of an event tag" do
      input = '[event name="x" start="y"][/event]'

      expect(detector.detect(input, 1)).to be_nil
    end
  end
end
