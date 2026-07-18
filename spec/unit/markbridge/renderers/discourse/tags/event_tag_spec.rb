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

      expect(tag.render(element, interface)).to eq("\n\n[event]ORIGINAL[/event]\n\n")
    end

    it "reconstructs BBCode with name and start when raw is missing" do
      element = Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-01-01 14:00")

      expect(tag.render(element, interface)).to eq(
        %(\n\n[event name="Meeting" start="2026-01-01 14:00"]\n[/event]\n\n),
      )
    end

    it "includes the end attribute when present" do
      element =
        Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-01-01", ends_at: "2026-01-02")

      expect(tag.render(element, interface)).to eq(
        %(\n\n[event name="Meeting" start="2026-01-01" end="2026-01-02"]\n[/event]\n\n),
      )
    end

    it "includes the status attribute when present" do
      element =
        Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-01-01", status: "public")

      expect(tag.render(element, interface)).to eq(
        %(\n\n[event name="Meeting" start="2026-01-01" status="public"]\n[/event]\n\n),
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
        %(\n\n[event name="Meeting" start="2026-01-01" timezone="Europe/Vienna"]\n[/event]\n\n),
      )
    end

    it "omits optional attributes when they are nil" do
      element = Markbridge::AST::Event.new(name: "X", starts_at: "Y")

      result = tag.render(element, interface)

      expect(result).not_to include("end=")
      expect(result).not_to include("status=")
      expect(result).not_to include("timezone=")
    end

    it "brackets a reconstructed event with leading and trailing blank lines" do
      element = Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-04-24 10:00")

      expect(tag.render(element, interface)).to start_with("\n\n[event")
      expect(tag.render(element, interface)).to end_with("[/event]\n\n")
    end

    it "brackets a raw-passthrough event the same way" do
      element =
        Markbridge::AST::Event.new(
          name: "Meeting",
          starts_at: "2026-04-24 10:00",
          raw: %([event name="Meeting" start="2026-04-24 10:00"]\n[/event]),
        )

      expect(tag.render(element, interface)).to start_with("\n\n[event")
      expect(tag.render(element, interface)).to end_with("[/event]\n\n")
    end

    # The stub is mode-agnostic: the same blank-line-bracketed island serves
    # both a standalone block in Markdown and the html_mode contract (which
    # is enforced by html_mode_contract_spec).
    it "emits the same island form in html_mode" do
      html_context = Markbridge::Renderers::Discourse::RenderContext.new([], html_mode: true)
      html_interface =
        Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, html_context)
      element = Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-01-01")

      expect(tag.render(element, html_interface)).to eq(
        %(\n\n[event name="Meeting" start="2026-01-01"]\n[/event]\n\n),
      )
    end
  end
end
