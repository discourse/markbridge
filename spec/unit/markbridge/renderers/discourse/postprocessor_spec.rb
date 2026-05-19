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

    context "with the default strip_trailing_invisibles: false" do
      it "keeps trailing ZWSP at line ends" do
        # U+200B is a real character in the output; default Postprocessor
        # leaves it alone.
        zwsp = "​"
        expect(postprocessor.call("hello#{zwsp}\nworld")).to eq("hello#{zwsp}\nworld")
      end

      it "keeps trailing NBSP at line ends" do
        nbsp = " "
        expect(postprocessor.call("hello#{nbsp}\nworld")).to eq("hello#{nbsp}\nworld")
      end
    end

    context "with strip_trailing_invisibles: true" do
      let(:postprocessor) { described_class.new(strip_trailing_invisibles: true) }

      it "strips trailing zero-width space at the end of a line" do
        zwsp = "​"
        expect(postprocessor.call("hello#{zwsp}\nworld")).to eq("hello\nworld")
      end

      it "strips trailing nbsp at the end of a line" do
        nbsp = " "
        expect(postprocessor.call("hello#{nbsp}\nworld")).to eq("hello\nworld")
      end

      it "strips every recognised invisible (ZWSP, ZWNJ, ZWJ, WJ, ZWNBSP) at end of line" do
        # All five zero-width format chars covered by TRAILING_INVISIBLE_RE.
        invisibles = "​‌‍⁠﻿"
        expect(postprocessor.call("hello#{invisibles}\nworld")).to eq("hello\nworld")
      end

      it "preserves trailing ASCII spaces — they encode Markdown hard line breaks" do
        # `hello  \nworld` (two trailing spaces) is the hard-line-break form;
        # the trailing-invisibles strip must not touch ASCII spaces.
        expect(postprocessor.call("hello  \nworld")).to eq("hello  \nworld")
      end

      it "preserves invisibles in the middle of content (only end-of-line is stripped)" do
        zwsp = "​"
        expect(postprocessor.call("before#{zwsp}inside")).to eq("before#{zwsp}inside")
      end

      it "strips trailing invisibles on every affected line, not just the first" do
        # gsub vs sub: with sub, only the first line's ZWSP gets cleaned.
        zwsp = "​"
        expect(postprocessor.call("first#{zwsp}\nsecond#{zwsp}")).to eq("first\nsecond")
      end
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
