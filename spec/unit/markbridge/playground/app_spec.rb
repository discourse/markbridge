# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../playground/app"

RSpec.describe Markbridge::Playground::App do
  subject(:app) { described_class.allocate }

  def convert(input, format: "bbcode", **options)
    app.send(:convert, format:, input:, options: options.transform_keys(&:to_s))
  end

  describe "#convert" do
    it "renders BBCode to Markdown and exposes the AST" do
      result = convert("[b]Hello[/b]")

      expect(result.fetch(:markdown)).to eq("**Hello**")
      expect(result.fetch(:ast)).to eq(%(Document\n└─ Bold\n   └─ Text text="Hello"))
      expect(result.fetch(:ast_json).fetch(:type)).to eq("Document")
      expect(result.fetch(:stats)).to include(node_count: 3, input_chars: 12, markdown_chars: 9)
      expect(result.fetch(:unknown_tags)).to eq([])
    end

    it "converts every format of the format switch" do
      inputs = {
        "bbcode" => "[i]x[/i]",
        "html" => "<i>x</i>",
        "text_formatter" => "<r><I><s>[i]</s>x<e>[/i]</e></I></r>",
        "media_wiki" => "''x''",
      }

      expect(inputs.keys).to eq(described_class::FORMATS.keys)
      inputs.each { |format, input| expect(convert(input, format:).fetch(:markdown)).to eq("*x*") }
    end

    it "raises for a format it does not know" do
      expect { convert("", format: "wat") }.to raise_error(ArgumentError, /unsupported format/)
    end

    it "writes colors, sizes and spoilers as BBCode by default" do
      result = convert("[color=red]a[/color] [size=120]b[/size] [spoiler]c[/spoiler]")

      expect(result.fetch(:markdown)).to eq(
        "[color=red]a[/color] [size=120]b[/size] [spoiler]c[/spoiler]",
      )
    end

    it "writes the text of colors and sizes for a site without discourse-bbcode" do
      result = convert("[color=red]a[/color] [size=120]b[/size]", bbcode: false)

      expect(result.fetch(:markdown)).to eq("a b")
    end

    it "writes the content of a spoiler for a site without spoiler-alert" do
      expect(convert("[spoiler]c[/spoiler]", spoiler: false).fetch(:markdown)).to eq("c")
    end

    it "normalizes the AST and reports what changed" do
      result = convert("[url=/a][url=/b]x[/url][/url]")

      expect(result.fetch(:markdown)).to eq("[x](/a)")
      expect(result.fetch(:diagnostics).fetch(:normalization)).to eq(
        [{ parent: "Url", child: "Url", strategy: :unwrap, count: 1 }],
      )
    end

    it "leaves the AST alone with normalize off" do
      result = convert("[url=/a][url=/b]x[/url][/url]", normalize: false)

      expect(result.fetch(:diagnostics).fetch(:normalization)).to eq([])
      expect(result.fetch(:ast)).to include("Url href=\"/b\"")
    end

    it "reports unknown tags and what the BBCode parser had to close" do
      result = convert("[mystery]a[/mystery] [b]bold [i]both[/b] [code]x")

      expect(result.fetch(:unknown_tags)).to eq([{ name: "mystery", count: 2 }])
      expect(result.fetch(:diagnostics)).to include(
        auto_closed_tags_count: (a_value > 0),
        unclosed_raw_tags: [{ name: "code", count: 1 }],
      )
    end

    it "has the same diagnostics for a parser that reports none" do
      expect(convert("<b>x</b>", format: "html").fetch(:diagnostics)).to eq(
        auto_closed_tags_count: 0,
        depth_exceeded_count: 0,
        unclosed_raw_tags: [],
        normalization: [],
      )
    end

    it "cooks a preview when there is an engine for it" do
      skip "no Node engine to cook with" unless described_class::COOKER.engine

      preview = convert("[b]Hello[/b]").fetch(:preview)

      expect(preview.fetch(:html)).to eq("<p><strong>Hello</strong></p>")
      expect(preview.fetch(:engine)).to eq(described_class::COOKER.engine)
    end
  end
end
