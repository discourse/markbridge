# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::MarkdownEscaper, "#initialize allow:" do
  describe "default behavior (allow: nil)" do
    let(:escaper) { described_class.new }

    it "escapes the leading dash of a bullet list" do
      expect(escaper.escape("- item")).to eq("\\- item")
    end

    it "escapes the leading plus of a bullet list" do
      expect(escaper.escape("+ item")).to eq("\\+ item")
    end

    it "escapes the leading star of a bullet list" do
      expect(escaper.escape("* item")).to eq("\\* item")
    end

    it "escapes the period of an ordered list" do
      expect(escaper.escape("1. item")).to eq("1\\. item")
    end

    it "escapes the close-paren of an ordered list" do
      expect(escaper.escape("1) item")).to eq("1\\) item")
    end
  end

  describe "allow: :bullet_list" do
    let(:escaper) { described_class.new(allow: :bullet_list) }

    it "passes a `- item` line through unescaped" do
      expect(escaper.escape("- item")).to eq("- item")
    end

    it "passes a `+ item` line through unescaped" do
      expect(escaper.escape("+ item")).to eq("+ item")
    end

    it "passes a `* item` line through unescaped" do
      expect(escaper.escape("* item")).to eq("* item")
    end

    it "still escapes ordered lists (only bullets allowed)" do
      expect(escaper.escape("1. item")).to eq("1\\. item")
    end

    it "still escapes a thematic break of dashes" do
      expect(escaper.escape("---")).to eq("\\-\\-\\-")
    end

    it "still escapes a thematic break of stars" do
      expect(escaper.escape("***")).to eq("\\*\\*\\*")
    end

    it "still escapes a setext underline of dashes after a paragraph" do
      expect(escaper.escape("paragraph\n---")).to eq("paragraph\n\\-\\-\\-")
    end

    it "still inline-escapes content after the bullet marker" do
      # The leading "- " passes through, but inline `*emphasis*` markers
      # inside the line still get escaped.
      expect(escaper.escape("- a *star* mark")).to eq("- a \\*star\\* mark")
    end
  end

  describe "allow: :ordered_list" do
    let(:escaper) { described_class.new(allow: :ordered_list) }

    it "passes a `1. item` line through unescaped" do
      expect(escaper.escape("1. item")).to eq("1. item")
    end

    it "passes a `1) item` line through unescaped" do
      expect(escaper.escape("1) item")).to eq("1) item")
    end

    it "passes large ordered numbers through unescaped" do
      expect(escaper.escape("99. item")).to eq("99. item")
    end

    it "still escapes bullet lists (only ordered allowed)" do
      expect(escaper.escape("- item")).to eq("\\- item")
    end

    it "still inline-escapes content after the marker" do
      # `1.` passes through; an inline `*emphasis*` in the rest
      # is still escaped.
      expect(escaper.escape("1. a *star* mark")).to eq("1. a \\*star\\* mark")
    end
  end

  describe "allow: :atx_heading" do
    let(:escaper) { described_class.new(allow: :atx_heading) }

    it "passes an h1 through unescaped" do
      expect(escaper.escape("# Heading")).to eq("# Heading")
    end

    it "passes an h6 through unescaped" do
      expect(escaper.escape("###### Heading")).to eq("###### Heading")
    end

    it "passes a 7-hash run through (CommonMark rejects 7+ hashes as a heading; not the kwarg's concern)" do
      # ATX_HEADING is `\#{1,6}(?=[ \t]|$)` — 7 hashes do not match,
      # so this never enters the allow-checked branch; behaviour is
      # identical to the default escaper.
      expect(escaper.escape("####### Heading")).to eq("####### Heading")
    end

    it "still inline-escapes content after the heading marker" do
      expect(escaper.escape("## a *star* h2")).to eq("## a \\*star\\* h2")
    end

    it "passes a `# ` empty heading through unescaped" do
      # Edge case from the plan: `# ` matches ATX_HEADING with empty
      # content. With :atx_heading allowed, the marker passes verbatim;
      # Discourse renders this as an empty <h1>.
      expect(escaper.escape("# ")).to eq("# ")
    end
  end

  describe "allow: :block_quote" do
    let(:escaper) { described_class.new(allow: :block_quote) }

    it "passes a `> quoted` line through unescaped" do
      expect(escaper.escape("> quoted")).to eq("> quoted")
    end

    it "still inline-escapes content after the `>`" do
      expect(escaper.escape("> a *star*")).to eq("> a \\*star\\*")
    end
  end

  describe "allow: :lists (alias for both)" do
    let(:escaper) { described_class.new(allow: :lists) }

    it "passes bullet lists through unescaped" do
      expect(escaper.escape("- item")).to eq("- item")
    end

    it "passes ordered lists through unescaped" do
      expect(escaper.escape("1. item")).to eq("1. item")
    end

    it "still escapes thematic breaks" do
      expect(escaper.escape("---")).to eq("\\-\\-\\-")
    end
  end

  describe "allow: as an Array" do
    it "accepts an Array of granular keys" do
      escaper = described_class.new(allow: %i[bullet_list ordered_list])

      expect(escaper.escape("- item")).to eq("- item")
      expect(escaper.escape("1. item")).to eq("1. item")
    end

    it "accepts an Array containing aliases (expanded)" do
      escaper = described_class.new(allow: [:lists])

      expect(escaper.escape("- item")).to eq("- item")
      expect(escaper.escape("1. item")).to eq("1. item")
    end
  end

  describe "allow: with unknown keys" do
    it "raises ArgumentError naming the unknown key and the recognised set" do
      expect { described_class.new(allow: :headings) }.to raise_error(ArgumentError) do |error|
        expect(error.message).to include("headings")
        expect(error.message).to include("bullet_list")
        expect(error.message).to include("ordered_list")
        expect(error.message).to include("atx_heading")
        expect(error.message).to include("block_quote")
        expect(error.message).to include("lists")
      end
    end

    it "raises when one element of an Array is unknown (others ignored)" do
      expect { described_class.new(allow: %i[bullet_list typos]) }.to raise_error(
        ArgumentError,
        /typos/,
      )
    end
  end

  describe "interaction with thematic breaks and setext underlines" do
    let(:escaper) { described_class.new(allow: :lists) }

    it "still escapes a thematic break of dashes even with :bullet_list allowed" do
      expect(escaper.escape("---")).to eq("\\-\\-\\-")
    end

    it "still escapes a setext-dash underline after a paragraph" do
      expect(escaper.escape("paragraph\n---")).to eq("paragraph\n\\-\\-\\-")
    end

    it "still escapes a thematic break of stars" do
      expect(escaper.escape("***")).to eq("\\*\\*\\*")
    end
  end

  describe "as plumbed through Markbridge.discourse_renderer" do
    it "forwards :lists to the constructed escaper" do
      renderer = Markbridge.discourse_renderer(allow: :lists)
      input = "- item"

      # The default postprocessor strips trailing whitespace; the
      # bullet line itself passes through unescaped.
      result = renderer.render(Markbridge::AST::Text.new(input))
      expect(result).to eq("- item")
    end

    it "is ignored when an explicit escaper: is supplied" do
      explicit = described_class.new # no allow
      renderer = Markbridge.discourse_renderer(escaper: explicit, allow: :lists)

      # The factory must not override an explicit escaper — the user's
      # instance wins.
      result = renderer.render(Markbridge::AST::Text.new("- item"))
      expect(result).to eq("\\- item")
    end
  end
end
