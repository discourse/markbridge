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

    it "forwards the handlers kwarg to the parser" do
      registry =
        Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
          r.register("highlight", :formatting, Markbridge::AST::Bold)
        end

      result = described_class.parse_mediawiki("<highlight>x</highlight>", handlers: registry)
      paragraph = result.ast.children.first

      expect(paragraph.children.first).to be_a(Markbridge::AST::Bold)
    end

    it "exposes unknown HTML-like inline tags via Parse#unknown_tags" do
      result = described_class.parse_mediawiki("hello <neverknown>world</neverknown>")

      expect(result.unknown_tags["neverknown"]).to eq(1)
    end
  end

  describe ".mediawiki_to_markdown" do
    it "renders MediaWiki to a Conversion" do
      expect(described_class.mediawiki_to_markdown("'''hi'''").markdown).to eq("**hi**")
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.mediawiki_to_markdown(nil) }.to raise_error(ArgumentError)
    end

    it "forwards the handlers kwarg through to the parser" do
      registry =
        Markbridge::Parsers::MediaWiki::InlineTagRegistry.build_from_default do |r|
          r.register("highlight", :formatting, Markbridge::AST::Bold)
        end

      result = described_class.mediawiki_to_markdown("<highlight>x</highlight>", handlers: registry)

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

  describe "raise_on_error: kwarg" do
    let(:exploding_tag) do
      Class.new(Markbridge::Renderers::Discourse::Tag) do
        def render(_element, _interface)
          raise "boom"
        end
      end
    end

    it "raises by default (raise_on_error: true)" do
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => exploding_tag.new })

      expect { described_class.bbcode_to_markdown("[b]hi[/b]", renderer:) }.to raise_error(/boom/)
    end

    it "swallows the error and surfaces it on Conversion#errors when raise_on_error: false" do
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => exploding_tag.new })

      result = described_class.bbcode_to_markdown("[b]hi[/b]", renderer:, raise_on_error: false)

      expect(result.markdown).to eq("")
      expect(result.errors.size).to eq(1)
      expect(result.errors.first.message).to match(/boom/)
    end

    it "returns an empty errors array when render succeeds" do
      result = described_class.bbcode_to_markdown("[b]hi[/b]", raise_on_error: false)

      expect(result.errors).to eq([])
    end
  end

  describe ".convert" do
    it "dispatches :bbcode to bbcode_to_markdown" do
      result = described_class.convert("[b]hi[/b]", format: :bbcode)

      expect(result.markdown).to eq("**hi**")
      expect(result.format).to eq(:bbcode)
    end

    it "dispatches :html to html_to_markdown" do
      expect(described_class.convert("<b>hi</b>", format: :html).markdown).to eq("**hi**")
    end

    it "dispatches :text_formatter_xml to text_formatter_xml_to_markdown" do
      xml = "<r><B><s>[b]</s>hi<e>[/b]</e></B></r>"

      expect(described_class.convert(xml, format: :text_formatter_xml).markdown).to eq("**hi**")
    end

    it "dispatches :mediawiki to mediawiki_to_markdown" do
      expect(described_class.convert("'''hi'''", format: :mediawiki).markdown).to eq("**hi**")
    end

    it "raises ArgumentError for unknown formats" do
      expect { described_class.convert("x", format: :unknown) }.to raise_error(
        ArgumentError,
        /unknown format/,
      )
    end

    it "forwards renderer: kwarg to the dispatched method" do
      fixed_bold =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            "B"
          end
        end
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => fixed_bold.new })

      expect(described_class.convert("[b]x[/b]", format: :bbcode, renderer:).markdown).to eq("B")
    end
  end

  describe ".render" do
    it "renders a Document AST through the default Discourse renderer" do
      doc = described_class.parse_bbcode("[b]hi[/b]").ast

      result = described_class.render(doc)

      expect(result).to be_a(Markbridge::Conversion)
      expect(result.markdown).to eq("**hi**")
      expect(result.format).to eq(:discourse)
    end

    it "honors a custom renderer:" do
      doc = described_class.parse_bbcode("[b]hi[/b]").ast
      fixed_bold =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            "BB"
          end
        end
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => fixed_bold.new })

      expect(described_class.render(doc, renderer:).markdown).to eq("BB")
    end

    it "raises ArgumentError for unknown render format" do
      doc = Markbridge::AST::Document.new
      expect { described_class.render(doc, format: :weird) }.to raise_error(
        ArgumentError,
        /unknown render format/,
      )
    end
  end

  describe ".discourse_renderer" do
    it "returns a Renderer that converts BBCode using a custom Tag" do
      fixed_bold =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_element, _interface)
            "BOLDED"
          end
        end

      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => fixed_bold.new })

      expect(described_class.bbcode_to_markdown("[b]hi[/b]", renderer:).markdown).to eq("BOLDED")
    end

    it "uses the default library when called without arguments" do
      renderer = described_class.discourse_renderer

      expect(described_class.bbcode_to_markdown("[b]hi[/b]", renderer:).markdown).to eq("**hi**")
    end

    it "honors unregister: by falling through to render_children" do
      renderer = described_class.discourse_renderer(unregister: [Markbridge::AST::Bold])

      # Without a Tag for AST::Bold the renderer falls through to
      # render_children, so the bold marker disappears entirely.
      expect(described_class.bbcode_to_markdown("[b]hi[/b]", renderer:).markdown).to eq("hi")
    end

    it "honors escape_hard_line_breaks: true via the sugar" do
      renderer = described_class.discourse_renderer(escape_hard_line_breaks: true)

      expect(described_class.bbcode_to_markdown("hello  \nworld", renderer:).markdown).to eq(
        "hello\nworld",
      )
    end

    it "preserves trailing-space hard line breaks by default" do
      renderer = described_class.discourse_renderer

      expect(described_class.bbcode_to_markdown("hello  \nworld", renderer:).markdown).to eq(
        "hello  \nworld",
      )
    end
  end

  describe "renderer: kwarg" do
    it "is honored by html_to_markdown" do
      fixed_bold =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_element, _interface)
            "HBOLD"
          end
        end
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => fixed_bold.new })

      expect(described_class.html_to_markdown("<b>hi</b>", renderer:).markdown).to eq("HBOLD")
    end

    it "is honored by mediawiki_to_markdown" do
      fixed_bold =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_element, _interface)
            "MBOLD"
          end
        end
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => fixed_bold.new })

      expect(described_class.mediawiki_to_markdown("'''hi'''", renderer:).markdown).to eq("MBOLD")
    end
  end

  class StringWrapper
    def initialize(s) = @s = s
    def to_s = @s
  end
end
