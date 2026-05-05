# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Postprocessor do
  let(:postprocessor) { described_class.new }

  describe "#call" do
    it "collapses runs of three or more newlines to exactly two" do
      expect(postprocessor.call("a\n\n\n\nb")).to eq("a\n\nb")
    end

    it "collapses every run of 3+ newlines, not just the first" do
      # Two distinct runs — `sub` would only catch the first.
      expect(postprocessor.call("a\n\n\nb\n\n\nc")).to eq("a\n\nb\n\nc")
    end

    it "removes whitespace-only lines (preserving multiple of them)" do
      expect(postprocessor.call("a\n   \nb\n\t\nc")).to eq("a\n\nb\n\nc")
    end

    it "strips leading and trailing whitespace from the document" do
      expect(postprocessor.call("   hi   ")).to eq("hi")
    end

    it "leaves a single blank line between paragraphs alone" do
      expect(postprocessor.call("a\n\nb")).to eq("a\n\nb")
    end
  end

  describe "DEFAULT" do
    it "is a Postprocessor instance" do
      expect(described_class::DEFAULT).to be_a(described_class)
    end

    it "behaves like a fresh instance" do
      expect(described_class::DEFAULT.call("a\n\n\nb")).to eq("a\n\nb")
    end
  end

  describe "as a Renderer dependency" do
    it "is invoked by Markbridge.bbcode_to_markdown via the renderer" do
      custom =
        Class.new(described_class) do
          def call(text)
            "PROCESSED:#{text.strip}"
          end
        end

      renderer = Markbridge.discourse_renderer(postprocessor: custom.new)

      expect(Markbridge.bbcode_to_markdown("[b]hi[/b]", renderer:).markdown).to eq(
        "PROCESSED:**hi**",
      )
    end
  end
end
