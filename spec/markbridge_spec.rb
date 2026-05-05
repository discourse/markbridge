# frozen_string_literal: true

RSpec.describe Markbridge do
  it "has a version number" do
    expect(Markbridge::VERSION).not_to be_nil
  end

  describe ".parse_bbcode" do
    it "returns a Parse with format :bbcode" do
      result = described_class.parse_bbcode("[b]hi[/b]")

      expect(result).to be_a(Markbridge::Parse)
      expect(result.format).to eq(:bbcode)
    end

    it "produces an AST that reflects the input" do
      result = described_class.parse_bbcode("[b]hi[/b]")

      expect(result.ast).to be_a(Markbridge::AST::Document)
      expect(result.ast.children.first).to be_a(Markbridge::AST::Bold)
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.parse_bbcode(nil) }.to raise_error(
        ArgumentError,
        /input cannot be nil/,
      )
    end

    it "coerces non-string input via to_s" do
      expect(described_class.parse_bbcode(123).ast).to be_a(Markbridge::AST::Document)
    end

    it "uses the provided handler registry" do
      registry = Markbridge::Parsers::BBCode::HandlerRegistry.new
      registry.register(
        "weird",
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      result = described_class.parse_bbcode("[weird]x[/weird]", handlers: registry)

      expect(result.ast.children.first).to be_a(Markbridge::AST::Italic)
    end

    it "exposes unknown_tags from the parser" do
      result = described_class.parse_bbcode("[neverknown]x[/neverknown]")

      expect(result.unknown_tags["neverknown"]).to eq(2)
    end

    it "exposes BBCode diagnostics" do
      result = described_class.parse_bbcode("[b]hi[/b]")

      expect(result.diagnostics).to include(
        :auto_closed_tags_count,
        :depth_exceeded_count,
        :unclosed_raw_tags,
      )
    end
  end

  describe ".bbcode_to_markdown" do
    it "returns a Conversion whose markdown reflects the input" do
      result = described_class.bbcode_to_markdown("[b]hi[/b]")

      expect(result).to be_a(Markbridge::Conversion)
      expect(result.markdown).to eq("**hi**")
    end

    it "delegates to_s to markdown for string-coercion contexts" do
      expect("got #{described_class.bbcode_to_markdown("[b]hi[/b]")}").to eq("got **hi**")
    end

    it "passes the provided handler registry through to the parser" do
      registry = Markbridge::Parsers::BBCode::HandlerRegistry.new
      registry.register(
        "b",
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      result = described_class.bbcode_to_markdown("[b]hi[/b]", handlers: registry)

      expect(result.markdown).to eq("*hi*")
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.bbcode_to_markdown(nil) }.to raise_error(ArgumentError)
    end

    it "exposes unknown_tags on the Conversion" do
      result = described_class.bbcode_to_markdown("[neverknown]x[/neverknown]")

      expect(result.unknown_tags["neverknown"]).to eq(2)
    end

    it "returns an empty emissions hash by default" do
      result = described_class.bbcode_to_markdown("[b]hi[/b]")

      expect(result.emissions).to eq({})
      expect(result.emitted(:upload)).to eq([])
    end

    it "returns an empty errors array by default" do
      expect(described_class.bbcode_to_markdown("[b]hi[/b]").errors).to eq([])
    end

    it "collapses three or more consecutive newlines to exactly two" do
      expect(described_class.bbcode_to_markdown("a\n\n\n\nb").markdown).to eq("a\n\nb")
    end

    it "removes whitespace-only lines" do
      expect(described_class.bbcode_to_markdown("a\n   \nb").markdown).to eq("a\n\nb")
    end

    it "strips leading and trailing whitespace from the final output" do
      expect(described_class.bbcode_to_markdown("   hi   ").markdown).to eq("hi")
    end
  end

  describe ".parse_html" do
    it "returns a Parse with format :html" do
      result = described_class.parse_html("<b>hi</b>")

      expect(result).to be_a(Markbridge::Parse)
      expect(result.format).to eq(:html)
      expect(result.ast).to be_a(Markbridge::AST::Document)
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.parse_html(nil) }.to raise_error(
        ArgumentError,
        /input cannot be nil/,
      )
    end

    it "uses the provided handler registry" do
      registry = Markbridge::Parsers::HTML::HandlerRegistry.new
      registry.register(
        "b",
        Markbridge::Parsers::HTML::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      result = described_class.parse_html("<b>hi</b>", handlers: registry)

      expect(result.ast.children.first).to be_a(Markbridge::AST::Italic)
    end
  end

  describe ".html_to_markdown" do
    it "renders HTML to a Conversion" do
      result = described_class.html_to_markdown("<b>hi</b>")

      expect(result).to be_a(Markbridge::Conversion)
      expect(result.markdown).to eq("**hi**")
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.html_to_markdown(nil) }.to raise_error(ArgumentError)
    end

    it "passes the provided handler registry through to the parser" do
      registry = Markbridge::Parsers::HTML::HandlerRegistry.new
      registry.register(
        "b",
        Markbridge::Parsers::HTML::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      result = described_class.html_to_markdown("<b>hi</b>", handlers: registry)

      expect(result.markdown).to eq("*hi*")
    end
  end

  describe ".parse_text_formatter_xml" do
    let(:xml) { "<r><B><s>[b]</s>hi<e>[/b]</e></B></r>" }

    it "returns a Parse with format :text_formatter_xml" do
      result = described_class.parse_text_formatter_xml(xml)

      expect(result).to be_a(Markbridge::Parse)
      expect(result.format).to eq(:text_formatter_xml)
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.parse_text_formatter_xml(nil) }.to raise_error(
        ArgumentError,
        /input cannot be nil/,
      )
    end

    it "uses the provided handler registry" do
      registry = Markbridge::Parsers::TextFormatter::HandlerRegistry.new
      registry.register(
        "B",
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      result = described_class.parse_text_formatter_xml(xml, handlers: registry)

      expect(result.ast.children.first).to be_a(Markbridge::AST::Italic)
    end
  end

  describe ".text_formatter_xml_to_markdown" do
    let(:xml) { "<r><B><s>[b]</s>hi<e>[/b]</e></B></r>" }

    it "renders TextFormatter XML to a Conversion" do
      result = described_class.text_formatter_xml_to_markdown(xml)

      expect(result.markdown).to eq("**hi**")
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.text_formatter_xml_to_markdown(nil) }.to raise_error(ArgumentError)
    end

    it "passes the provided handler registry through to the parser" do
      registry = Markbridge::Parsers::TextFormatter::HandlerRegistry.new
      registry.register(
        "B",
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      result = described_class.text_formatter_xml_to_markdown(xml, handlers: registry)

      expect(result.markdown).to eq("*hi*")
    end
  end

  describe ".parse_mediawiki" do
    it "returns a Parse with format :mediawiki" do
      result = described_class.parse_mediawiki("'''hi'''")

      expect(result).to be_a(Markbridge::Parse)
      expect(result.format).to eq(:mediawiki)
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.parse_mediawiki(nil) }.to raise_error(
        ArgumentError,
        /input cannot be nil/,
      )
    end

    it "coerces non-string input via to_s" do
      expect(described_class.parse_mediawiki(123).ast).to be_a(Markbridge::AST::Document)
    end

    it "forwards the inline_tag_registry kwarg to the parser" do
      registry =
        Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
          r.register("highlight", :formatting, Markbridge::AST::Bold)
        end

      result =
        described_class.parse_mediawiki("<highlight>x</highlight>", inline_tag_registry: registry)
      paragraph = result.ast.children.first

      expect(paragraph.children.first).to be_a(Markbridge::AST::Bold)
    end
  end

  describe ".mediawiki_to_markdown" do
    it "renders MediaWiki to a Conversion" do
      expect(described_class.mediawiki_to_markdown("'''hi'''").markdown).to eq("**hi**")
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.mediawiki_to_markdown(nil) }.to raise_error(ArgumentError)
    end

    it "forwards the inline_tag_registry kwarg through to the parser" do
      registry =
        Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
          r.register("highlight", :formatting, Markbridge::AST::Bold)
        end

      result =
        described_class.mediawiki_to_markdown(
          "<highlight>x</highlight>",
          inline_tag_registry: registry,
        )

      expect(result.markdown).to eq("**x**")
    end
  end

  describe "cleanup behavior in *_to_markdown methods" do
    it "removes whitespace-only lines (preserving multiple of them)" do
      expect(described_class.bbcode_to_markdown("a\n   \nb\n\t\nc").markdown).to eq("a\n\nb\n\nc")
    end

    it "collapses every run of 3+ newlines, not just the first" do
      expect(described_class.bbcode_to_markdown("a\n\n\nb\n\n\nc").markdown).to eq("a\n\nb\n\nc")
    end

    it "preserves paragraph breaks (single blank line) without collapsing" do
      expect(described_class.bbcode_to_markdown("a\n\nb").markdown).to eq("a\n\nb")
    end
  end

  describe ".parse_mediawiki coercion" do
    it "calls to_s on the input (not on Markbridge itself)" do
      wrapper = StringWrapper.new("'''hi'''")

      result = described_class.parse_mediawiki(wrapper)

      expect(result.ast.children.first).to be_a(Markbridge::AST::Paragraph)
      expect(result.ast.children.first.children.first).to be_a(Markbridge::AST::Bold)
    end
  end

  class StringWrapper
    def initialize(s) = @s = s
    def to_s = @s
  end
end
