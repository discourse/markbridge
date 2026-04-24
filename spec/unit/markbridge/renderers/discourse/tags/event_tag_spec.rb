# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Tags::EventTag do
  let(:tag) { described_class.new }
  let(:renderer) { Markbridge::Renderers::Discourse::Renderer.new }
  let(:context) { Markbridge::Renderers::Discourse::RenderContext.new }
  let(:interface) { Markbridge::Renderers::Discourse::RenderingInterface.new(renderer, context) }

  describe "#render" do
    it "emits a trailing blank line after a reconstructed event" do
      element = Markbridge::AST::Event.new(name: "Meeting", starts_at: "2026-04-24 10:00")

      result = tag.render(element, interface)

      expect(result).to end_with("[/event]\n\n")
    end

    it "emits a trailing blank line after a raw-passthrough event" do
      element =
        Markbridge::AST::Event.new(
          name: "Meeting",
          starts_at: "2026-04-24 10:00",
          raw: %([event name="Meeting" start="2026-04-24 10:00"]\n[/event]),
        )

      result = tag.render(element, interface)

      expect(result).to eq(%([event name="Meeting" start="2026-04-24 10:00"]\n[/event]\n\n))
    end
  end
end
