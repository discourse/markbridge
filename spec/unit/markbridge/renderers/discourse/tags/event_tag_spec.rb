# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::EventTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "returns the raw BBCode verbatim when present" do
      element =
        Markbridge::AST::Event.new(
          name: "Meeting",
          starts_at: "2026-01-01",
          raw: "[event]ORIGINAL[/event]",
        )

      expect(tag.render(element, interface)).to eq("[event]ORIGINAL[/event]\n\n")
    end

    it "reconstructs BBCode with name and start when raw is missing" do
      element = Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-01-01 14:00")

      expect(tag.render(element, interface)).to eq(
        %([event name="Meeting" start="2026-01-01 14:00"]\n[/event]\n\n),
      )
    end

    it "includes the end attribute when present" do
      element =
        Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-01-01", ends_at: "2026-01-02")

      expect(tag.render(element, interface)).to eq(
        %([event name="Meeting" start="2026-01-01" end="2026-01-02"]\n[/event]\n\n),
      )
    end

    it "includes the status attribute when present" do
      element =
        Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-01-01", status: "public")

      expect(tag.render(element, interface)).to eq(
        %([event name="Meeting" start="2026-01-01" status="public"]\n[/event]\n\n),
      )
    end

    it "includes the timezone attribute when present" do
      element =
        Markbridge::AST::Event.new(
          name: "Meeting",
          starts_at: "2026-01-01",
          timezone: "Europe/Vienna",
        )

      expect(tag.render(element, interface)).to eq(
        %([event name="Meeting" start="2026-01-01" timezone="Europe/Vienna"]\n[/event]\n\n),
      )
    end

    it "omits optional attributes when they are nil" do
      element = Markbridge::AST::Event.new(name: "X", starts_at: "Y")

      result = tag.render(element, interface)

      expect(result).not_to include("end=")
      expect(result).not_to include("status=")
      expect(result).not_to include("timezone=")
    end

    it "emits a trailing blank line after a reconstructed event" do
      element = Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-04-24 10:00")

      expect(tag.render(element, interface)).to end_with("[/event]\n\n")
    end

    it "emits a trailing blank line after a raw-passthrough event" do
      element =
        Markbridge::AST::Event.new(
          name: "Meeting",
          starts_at: "2026-04-24 10:00",
          raw: %([event name="Meeting" start="2026-04-24 10:00"]\n[/event]),
        )

      expect(tag.render(element, interface)).to end_with("[/event]\n\n")
    end
  end
end
