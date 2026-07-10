# frozen_string_literal: true

RSpec.describe Markbridge do
  # Append a link wrapping an image — a Discourse normalization violation
  # (the image is hoisted out) — so a test can prove whether the +normalize:+
  # pass ran, regardless of the source format.
  def append_linked_image(ast)
    url = Markbridge::AST::Url.new(href: "https://example.com")
    url << Markbridge::AST::Image.new(src: "https://example.com/pic.png")
    ast << url
  end

  HOISTED = [{ parent: "Url", child: "Image", strategy: :hoist_after, count: 1 }].freeze
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

    it "exposes BBCode diagnostics with integer counters and an unclosed-raw-tags hash" do
      result = described_class.parse_bbcode("[b]hi[/b]")

      expect(result.diagnostics[:auto_closed_tags_count]).to eq(0)
      expect(result.diagnostics[:depth_exceeded_count]).to eq(0)
      expect(result.diagnostics[:unclosed_raw_tags]).to eq({})
    end

    it "increments auto_closed_tags_count when the parser auto-closes a tag" do
      # [b][i]x[/b] forces auto-close of [i] when [/b] arrives.
      result = described_class.parse_bbcode("[b][i]x[/b]")

      expect(result.diagnostics[:auto_closed_tags_count]).to be > 0
    end
  end

  describe ".bbcode_to_markdown" do
    it "normalizes the AST by default" do
      conversion = described_class.bbcode_to_markdown("hi") { |ast| append_linked_image(ast) }

      expect(conversion.diagnostics[:normalization]).to eq(HOISTED)
    end

    it "does not normalize when normalize: false" do
      conversion =
        described_class.bbcode_to_markdown("hi", normalize: false) do |ast|
          append_linked_image(ast)
        end

      expect(conversion.diagnostics[:normalization]).to be_nil
    end

    it "returns a Conversion whose markdown reflects the input" do
      result = described_class.bbcode_to_markdown("[b]hi[/b]")

      expect(result).to be_a(Markbridge::Conversion)
      expect(result.markdown).to eq("**hi**")
    end

    it "carries the parsed AST through to Conversion#ast" do
      result = described_class.bbcode_to_markdown("[b]hi[/b]")

      expect(result.ast).to be_a(Markbridge::AST::Document)
      expect(result.ast.children.first).to be_a(Markbridge::AST::Bold)
    end

    it "carries the parsed format through to Conversion#format" do
      expect(described_class.bbcode_to_markdown("[b]hi[/b]").format).to eq(:bbcode)
    end

    it "carries parser-side diagnostics through to Conversion#diagnostics" do
      result = described_class.bbcode_to_markdown("[b][i]x[/b]")

      expect(result.diagnostics[:auto_closed_tags_count]).to be > 0
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

    it "lets render-time errors propagate by default (raise_on_error defaults to true)" do
      tag =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            raise "boom"
          end
        end
      renderer = described_class.discourse_renderer(tags: { Markbridge::AST::Bold => tag.new })

      expect { described_class.bbcode_to_markdown("[b]x[/b]", renderer:) }.to raise_error(/boom/)
    end

    it "yields the AST to a block between parse and render so callers can mutate it" do
      result =
        described_class.bbcode_to_markdown("[b]hi[/b]") do |ast|
          ast << Markbridge::AST::Text.new(" extra")
        end

      expect(result.markdown).to eq("**hi** extra")
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

    it "coerces non-string input via to_s" do
      expect(described_class.parse_html(123).ast).to be_a(Markbridge::AST::Document)
    end

    it "exposes unknown_tags from the parser as a queryable Hash" do
      result = described_class.parse_html("<neverknown>x</neverknown>")

      expect(result.unknown_tags["neverknown"]).to eq(1)
    end

    it "exposes an empty diagnostics Hash" do
      expect(described_class.parse_html("<b>hi</b>").diagnostics).to eq({})
    end

    it "accepts a pre-parsed Nokogiri::HTML::DocumentFragment without re-parsing" do
      fragment = Nokogiri::HTML.fragment("<p><b>hi</b></p>")
      result = described_class.parse_html(fragment)

      expect(result.ast.children[0]).to be_a(Markbridge::AST::Paragraph)
    end
  end

  describe ".html_to_markdown" do
    it "normalizes the AST by default" do
      conversion = described_class.html_to_markdown("<b>hi</b>") { |ast| append_linked_image(ast) }

      expect(conversion.diagnostics[:normalization]).to eq(HOISTED)
    end

    it "does not normalize when normalize: false" do
      conversion =
        described_class.html_to_markdown("<b>hi</b>", normalize: false) do |ast|
          append_linked_image(ast)
        end

      expect(conversion.diagnostics[:normalization]).to be_nil
    end

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

    it "lets render-time errors propagate by default (raise_on_error defaults to true)" do
      tag =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            raise "boom"
          end
        end
      renderer = described_class.discourse_renderer(tags: { Markbridge::AST::Bold => tag.new })

      expect { described_class.html_to_markdown("<b>x</b>", renderer:) }.to raise_error(/boom/)
    end

    it "yields the AST to a block between parse and render so callers can mutate it" do
      result =
        described_class.html_to_markdown("<b>hi</b>") do |ast|
          ast << Markbridge::AST::Text.new(" extra")
        end

      expect(result.markdown).to eq("**hi** extra")
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

    it "coerces non-string input via to_s" do
      expect(described_class.parse_text_formatter_xml(123).ast).to be_a(Markbridge::AST::Document)
    end

    it "exposes unknown_tags from the parser as a queryable Hash" do
      result = described_class.parse_text_formatter_xml("<r><NEVERKNOWN>x</NEVERKNOWN></r>")

      expect(result.unknown_tags["NEVERKNOWN"]).to eq(1)
    end

    it "exposes an empty diagnostics Hash" do
      expect(described_class.parse_text_formatter_xml(xml).diagnostics).to eq({})
    end

    it "accepts a pre-parsed Nokogiri::XML::Document without re-parsing" do
      xml_doc = Nokogiri.XML("<r><B>hi</B></r>")
      result = described_class.parse_text_formatter_xml(xml_doc)

      expect(result.ast.children[0]).to be_a(Markbridge::AST::Bold)
    end
  end

  describe ".text_formatter_xml_to_markdown" do
    let(:xml) { "<r><B><s>[b]</s>hi<e>[/b]</e></B></r>" }

    it "normalizes the AST by default" do
      conversion =
        described_class.text_formatter_xml_to_markdown(xml) { |ast| append_linked_image(ast) }

      expect(conversion.diagnostics[:normalization]).to eq(HOISTED)
    end

    it "does not normalize when normalize: false" do
      conversion =
        described_class.text_formatter_xml_to_markdown(xml, normalize: false) do |ast|
          append_linked_image(ast)
        end

      expect(conversion.diagnostics[:normalization]).to be_nil
    end

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

    it "lets render-time errors propagate by default (raise_on_error defaults to true)" do
      tag =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            raise "boom"
          end
        end
      renderer = described_class.discourse_renderer(tags: { Markbridge::AST::Bold => tag.new })

      expect { described_class.text_formatter_xml_to_markdown(xml, renderer:) }.to raise_error(
        /boom/,
      )
    end

    it "yields the AST to a block between parse and render so callers can mutate it" do
      result =
        described_class.text_formatter_xml_to_markdown(xml) do |ast|
          ast << Markbridge::AST::Text.new(" extra")
        end

      expect(result.markdown).to eq("**hi** extra")
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

    it "exposes an empty diagnostics Hash so callers can index into it without nil-checks" do
      expect(described_class.parse_mediawiki("'''hi'''").diagnostics).to eq({})
    end
  end

  describe ".mediawiki_to_markdown" do
    it "normalizes the AST by default" do
      conversion =
        described_class.mediawiki_to_markdown("'''hi'''") { |ast| append_linked_image(ast) }

      expect(conversion.diagnostics[:normalization]).to eq(HOISTED)
    end

    it "does not normalize when normalize: false" do
      conversion =
        described_class.mediawiki_to_markdown("'''hi'''", normalize: false) do |ast|
          append_linked_image(ast)
        end

      expect(conversion.diagnostics[:normalization]).to be_nil
    end

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

    it "lets render-time errors propagate by default (raise_on_error defaults to true)" do
      tag =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            raise "boom"
          end
        end
      renderer = described_class.discourse_renderer(tags: { Markbridge::AST::Bold => tag.new })

      expect { described_class.mediawiki_to_markdown("'''x'''", renderer:) }.to raise_error(/boom/)
    end

    it "yields the AST to a block between parse and render so callers can mutate it" do
      result =
        described_class.mediawiki_to_markdown("'''hi'''") do |ast|
          ast << Markbridge::AST::Text.new(" extra")
        end

      # MediaWiki wraps the Bold in a Paragraph, so the appended Text is a
      # second top-level child and a paragraph break separates them.
      expect(result.markdown).to eq("**hi**\n\n extra")
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

    it "forwards renderer: kwarg through the :html branch" do
      fixed_bold =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            "HB"
          end
        end
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => fixed_bold.new })

      expect(described_class.convert("<b>x</b>", format: :html, renderer:).markdown).to eq("HB")
    end

    it "forwards renderer: kwarg through the :mediawiki branch" do
      fixed_bold =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            "MB"
          end
        end
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => fixed_bold.new })

      expect(described_class.convert("'''x'''", format: :mediawiki, renderer:).markdown).to eq("MB")
    end

    it "forwards renderer: kwarg through the :text_formatter_xml branch" do
      fixed_bold =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            "TB"
          end
        end
      renderer =
        described_class.discourse_renderer(tags: { Markbridge::AST::Bold => fixed_bold.new })

      result = described_class.convert("<r><B>x</B></r>", format: :text_formatter_xml, renderer:)
      expect(result.markdown).to eq("TB")
    end

    it "forwards a block to the :bbcode branch" do
      result =
        described_class.convert("[b]hi[/b]", format: :bbcode) do |ast|
          ast << Markbridge::AST::Text.new(" extra")
        end

      expect(result.markdown).to eq("**hi** extra")
    end

    it "forwards a block to the :html branch" do
      result =
        described_class.convert("<b>hi</b>", format: :html) do |ast|
          ast << Markbridge::AST::Text.new(" extra")
        end

      expect(result.markdown).to eq("**hi** extra")
    end

    it "forwards a block to the :text_formatter_xml branch" do
      result =
        described_class.convert("<r><B>hi</B></r>", format: :text_formatter_xml) do |ast|
          ast << Markbridge::AST::Text.new(" extra")
        end

      expect(result.markdown).to eq("**hi** extra")
    end

    it "forwards a block to the :mediawiki branch" do
      result =
        described_class.convert("'''hi'''", format: :mediawiki) do |ast|
          ast << Markbridge::AST::Text.new(" extra")
        end

      # Paragraph wrap puts the appended Text after a blank line.
      expect(result.markdown).to eq("**hi**\n\n extra")
    end
  end

  describe ".render" do
    it "normalizes the AST by default" do
      ast = Markbridge::AST::Document.new
      append_linked_image(ast)

      expect(described_class.render(ast).diagnostics[:normalization]).to eq(HOISTED)
    end

    it "does not normalize when normalize: false" do
      ast = Markbridge::AST::Document.new
      append_linked_image(ast)

      expect(described_class.render(ast, normalize: false).diagnostics[:normalization]).to be_nil
    end

    it "uses a passed Normalizer, including a subclass instance (is_a?, not instance_of?)" do
      subclass = Class.new(Markbridge::Normalizer)
      normalizer = subclass.for(:discourse)
      normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Image, strategy: :drop)
      ast = Markbridge::AST::Document.new
      append_linked_image(ast)

      conversion = described_class.render(ast, normalize: normalizer)

      # The subclass instance is accepted and its :drop rule applied; with
      # instance_of? it would be rejected and the default :hoist_after used.
      expect(conversion.diagnostics[:normalization]).to eq(
        [{ parent: "Url", child: "Image", strategy: :drop, count: 1 }],
      )
      expect(conversion.ast.descendants(Markbridge::AST::Image)).to be_empty
    end

    it "renders a Document AST through the default Discourse renderer" do
      doc = described_class.parse_bbcode("[b]hi[/b]").ast

      result = described_class.render(doc)

      expect(result).to be_a(Markbridge::Conversion)
      expect(result.markdown).to eq("**hi**")
    end

    it "reports a nil format for bare AST input (no source document was parsed)" do
      # :format means *source* format everywhere else; a programmatically
      # built AST has none, and pretending it was :discourse would
      # conflate the render target with the parse source.
      doc = described_class.parse_bbcode("[b]hi[/b]").ast

      expect(described_class.render(doc).format).to be_nil
    end

    it "preserves the original Document identity when given one (no extra wrapping)" do
      doc = described_class.parse_bbcode("[b]hi[/b]").ast

      expect(described_class.render(doc).ast).to be(doc)
    end

    it "wraps a bare non-Document node in a Document so Conversion#ast is always one" do
      bold = Markbridge::AST::Bold.new
      bold << Markbridge::AST::Text.new("hi")

      result = described_class.render(bold)

      expect(result.markdown).to eq("**hi**")
      expect(result.ast).to be_a(Markbridge::AST::Document)
      expect(result.ast.children).to eq([bold])
      # The synthesized Parse carries empty (queryable) hashes, not nil.
      expect(result.unknown_tags).to eq({})
      expect(result.diagnostics).to eq({})
    end

    it "exposes the synthesized Parse via Conversion#parsed" do
      doc = described_class.parse_bbcode("[b]hi[/b]").ast

      result = described_class.render(doc)

      expect(result.parsed).to be_a(Markbridge::Parse)
      expect(result.parsed.ast).to be(doc)
    end

    it "carries the given Parse through to Conversion#parsed unchanged" do
      parse = described_class.parse_bbcode("[b]hi[/b]")

      expect(described_class.render(parse).parsed).to be(parse)
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

    it "raises ArgumentError for unknown render format with the offending format inspected" do
      doc = Markbridge::AST::Document.new
      expect { described_class.render(doc, format: :weird) }.to raise_error(
        ArgumentError,
        "unknown render format :weird",
      )
    end

    it "lets render-time errors propagate by default (raise_on_error defaults to true)" do
      tag =
        Class.new(Markbridge::Renderers::Discourse::Tag) do
          def render(_e, _i)
            raise "boom"
          end
        end
      renderer = described_class.discourse_renderer(tags: { Markbridge::AST::Bold => tag.new })
      doc = described_class.parse_bbcode("[b]x[/b]").ast

      expect { described_class.render(doc, renderer:) }.to raise_error(/boom/)
    end

    it "carries the AST through to Conversion#ast" do
      doc = described_class.parse_bbcode("[b]hi[/b]").ast

      expect(described_class.render(doc).ast).to be(doc)
    end

    it "exposes empty Hashes for unknown_tags and diagnostics (no parser-side data available)" do
      result = described_class.render(Markbridge::AST::Document.new)

      expect(result.unknown_tags).to eq({})
      expect(result.diagnostics).to eq({})
    end

    it "exposes an empty Array for errors when render succeeds" do
      expect(described_class.render(Markbridge::AST::Document.new).errors).to eq([])
    end

    context "with a Parse argument" do
      it "renders the Parse's AST" do
        parse = described_class.parse_bbcode("[b]hi[/b]")

        expect(described_class.render(parse).markdown).to eq("**hi**")
      end

      it "carries the Parse's source format through to Conversion#format" do
        parse = described_class.parse_bbcode("[b]hi[/b]")

        expect(described_class.render(parse).format).to eq(:bbcode)
      end

      it "carries the Parse's unknown_tags forward" do
        parse = described_class.parse_bbcode("[neverknown]x[/neverknown]")

        expect(described_class.render(parse).unknown_tags["neverknown"]).to eq(2)
      end

      it "carries the Parse's diagnostics forward" do
        parse = described_class.parse_bbcode("[b][i]x[/b]")

        expect(described_class.render(parse).diagnostics[:auto_closed_tags_count]).to be > 0
      end

      it "renders mutations made to the Parse's AST after parsing" do
        parse = described_class.parse_bbcode("[b]hi[/b]")
        parse.ast << Markbridge::AST::Text.new(" extra")

        expect(described_class.render(parse).markdown).to eq("**hi** extra")
      end
    end

    context "with neither a Parse nor an AST::Node" do
      it "raises ArgumentError naming the offending class" do
        expect { described_class.render("a string") }.to raise_error(
          ArgumentError,
          /expected Parse or AST::Node, got String/,
        )
      end
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

    it "uses an explicit tag_library: as the base when one is provided" do
      base = Markbridge::Renderers::Discourse::TagLibrary.new
      base.register(
        Markbridge::AST::Bold,
        Markbridge::Renderers::Discourse::Tag.new { |_e, _i| "FROM-BASE" },
      )

      renderer = described_class.discourse_renderer(tag_library: base)

      # No bold registered in the *default* library would render as "**" markers; the
      # explicit base is being used (returning the literal "FROM-BASE").
      expect(described_class.bbcode_to_markdown("[b]x[/b]", renderer:).markdown).to eq("FROM-BASE")
    end

    it "dups an explicit tag_library: before mutating, so the caller's library is untouched" do
      # tags: / unregister: are mutating operations. Without the dup the
      # factory would silently rewrite the caller's library — surprising
      # for anyone composing multiple renderers against the same base.
      base = Markbridge::Renderers::Discourse::TagLibrary.new
      original_bold = Markbridge::Renderers::Discourse::Tags::BoldTag.new
      base.register(Markbridge::AST::Bold, original_bold)

      described_class.discourse_renderer(
        tag_library: base,
        tags: {
          Markbridge::AST::Bold =>
            Markbridge::Renderers::Discourse::Tag.new { |_e, _i| "OVERRIDDEN" },
        },
        unregister: [Markbridge::AST::Italic],
      )

      expect(base[Markbridge::AST::Bold]).to be(original_bold)
    end

    it "forwards an explicit postprocessor: through to the Renderer" do
      shouting =
        Class.new(Markbridge::Renderers::Discourse::Postprocessor) do
          def call(text)
            text.upcase
          end
        end

      renderer = described_class.discourse_renderer(postprocessor: shouting.new)

      expect(described_class.bbcode_to_markdown("[b]hi[/b]", renderer:).markdown).to eq("**HI**")
    end

    it "forwards :strip_trailing_invisibles to the constructed Postprocessor" do
      zwsp = "​"
      renderer = described_class.discourse_renderer(strip_trailing_invisibles: true)

      result = described_class.html_to_markdown("<p>hello#{zwsp}</p>", renderer:)

      expect(result.markdown).to eq("hello")
    end

    it "defaults strip_trailing_invisibles to false (invisibles survive)" do
      zwsp = "​"
      renderer = described_class.discourse_renderer

      result = described_class.html_to_markdown("<p>hello#{zwsp}</p>", renderer:)

      expect(result.markdown).to eq("hello#{zwsp}")
    end

    it "forwards :allow to the constructed escaper (lists alias)" do
      renderer = described_class.discourse_renderer(allow: :lists)

      # The `-` and `1.` markers would normally be escaped to `\-`
      # and `1\.`. With allow: :lists they pass through verbatim.
      expect(renderer.render(Markbridge::AST::Text.new("- item"))).to eq("- item")
      expect(renderer.render(Markbridge::AST::Text.new("1. item"))).to eq("1. item")
    end

    it "uses IdentityEscaper when escape: false" do
      renderer = described_class.discourse_renderer(escape: false)

      # `*raw*` would normally be escaped to `\*raw\*`. With
      # IdentityEscaper, it survives.
      result = described_class.html_to_markdown("*raw*", renderer:)
      expect(result.markdown).to eq("*raw*")
    end

    it "raises when escape: false is combined with escape_hard_line_breaks: true" do
      expect {
        described_class.discourse_renderer(escape: false, escape_hard_line_breaks: true)
      }.to raise_error(ArgumentError, /mutually exclusive/)
    end

    it "raises when escape: false is combined with allow:" do
      expect { described_class.discourse_renderer(escape: false, allow: :lists) }.to raise_error(
        ArgumentError,
        /mutually exclusive/,
      )
    end

    it "lets an explicit escaper: win even when escape: false is given" do
      explicit = Markbridge::Renderers::Discourse::MarkdownEscaper.new
      renderer = described_class.discourse_renderer(escaper: explicit, escape: false)

      result = described_class.html_to_markdown("a*b", renderer:)
      expect(result.markdown).to eq('a\*b')
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
