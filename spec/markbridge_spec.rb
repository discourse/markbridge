# frozen_string_literal: true

RSpec.describe Markbridge do
  after { described_class.reset_defaults! }

  fixed_output_tag =
    Class.new(Markbridge::Renderers::Discourse::Tag) do
      def initialize(output)
        super()
        @output = output
      end

      def render(_element, _interface, **_kwargs)
        @output
      end
    end

  it "has a version number" do
    expect(Markbridge::VERSION).not_to be nil
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(Markbridge::Configuration)
    end

    it "memoizes the configuration" do
      expect(described_class.configuration).to be(described_class.configuration)
    end
  end

  describe ".configure" do
    it "yields the configuration" do
      yielded = nil
      described_class.configure { |config| yielded = config }

      expect(yielded).to be(described_class.configuration)
    end
  end

  describe ".reset_defaults!" do
    it "resets the configuration" do
      old_config = described_class.configuration
      described_class.reset_defaults!
      expect(described_class.configuration).not_to be(old_config)
    end

    it "resets the default handlers" do
      old = described_class.default_handlers
      described_class.reset_defaults!
      expect(described_class.default_handlers).not_to be(old)
    end

    it "resets the default HTML handlers" do
      old = described_class.default_html_handlers
      described_class.reset_defaults!
      expect(described_class.default_html_handlers).not_to be(old)
    end

    it "resets the default tag library" do
      old = described_class.default_tag_library
      described_class.reset_defaults!
      expect(described_class.default_tag_library).not_to be(old)
    end

    it "resets the default text formatter handlers" do
      old = described_class.default_text_formatter_handlers
      described_class.reset_defaults!
      expect(described_class.default_text_formatter_handlers).not_to be(old)
    end
  end

  describe ".default_handlers" do
    it "returns a BBCode HandlerRegistry" do
      expect(described_class.default_handlers).to be_a(Markbridge::Parsers::BBCode::HandlerRegistry)
    end

    it "memoizes the registry across calls" do
      expect(described_class.default_handlers).to be(described_class.default_handlers)
    end
  end

  describe ".default_html_handlers" do
    it "returns an HTML HandlerRegistry" do
      expect(described_class.default_html_handlers).to be_a(
        Markbridge::Parsers::HTML::HandlerRegistry,
      )
    end

    it "memoizes the registry across calls" do
      expect(described_class.default_html_handlers).to be(described_class.default_html_handlers)
    end
  end

  describe ".default_tag_library" do
    it "returns a Discourse TagLibrary" do
      expect(described_class.default_tag_library).to be_a(
        Markbridge::Renderers::Discourse::TagLibrary,
      )
    end

    it "memoizes the library across calls" do
      expect(described_class.default_tag_library).to be(described_class.default_tag_library)
    end
  end

  describe ".default_text_formatter_handlers" do
    it "returns a TextFormatter HandlerRegistry" do
      expect(described_class.default_text_formatter_handlers).to be_a(
        Markbridge::Parsers::TextFormatter::HandlerRegistry,
      )
    end

    it "memoizes the registry across calls" do
      expect(described_class.default_text_formatter_handlers).to be(
        described_class.default_text_formatter_handlers,
      )
    end
  end

  describe ".parse_bbcode" do
    it "returns an AST::Document" do
      expect(described_class.parse_bbcode("[b]hi[/b]")).to be_a(Markbridge::AST::Document)
    end

    it "produces children that reflect the input" do
      doc = described_class.parse_bbcode("[b]hi[/b]")

      expect(doc.children.first).to be_a(Markbridge::AST::Bold)
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.parse_bbcode(nil) }.to raise_error(
        ArgumentError,
        /input cannot be nil/,
      )
    end

    it "coerces non-string input via to_s" do
      expect(described_class.parse_bbcode(123)).to be_a(Markbridge::AST::Document)
    end

    it "uses Markbridge.default_handlers when handlers not provided" do
      # Register a custom tag on the shared default registry; it must be
      # picked up by parse_bbcode (proves the default is reused, not re-built)
      described_class.default_handlers.register(
        "customtag",
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Bold),
      )

      doc = described_class.parse_bbcode("[customtag]x[/customtag]")

      expect(doc.children.first).to be_a(Markbridge::AST::Bold)
    end

    it "uses the provided handler registry" do
      registry = Markbridge::Parsers::BBCode::HandlerRegistry.new
      registry.register(
        "weird",
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      doc = described_class.parse_bbcode("[weird]x[/weird]", handlers: registry)

      expect(doc.children.first).to be_a(Markbridge::AST::Italic)
    end
  end

  describe ".bbcode_to_markdown" do
    it "renders BBCode to markdown" do
      expect(described_class.bbcode_to_markdown("[b]hi[/b]")).to eq("**hi**")
    end

    it "passes the provided handler registry through to the parser" do
      registry = Markbridge::Parsers::BBCode::HandlerRegistry.new
      registry.register(
        "b",
        Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      # Custom registry maps [b] to italic; markdown output uses *_*
      expect(described_class.bbcode_to_markdown("[b]hi[/b]", handlers: registry)).to eq("*hi*")
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.bbcode_to_markdown(nil) }.to raise_error(ArgumentError)
    end

    it "respects escape_hard_line_breaks configuration" do
      described_class.configure { |c| c.escape_hard_line_breaks = true }

      result = described_class.bbcode_to_markdown("hello  \nworld")
      expect(result).to eq("hello\nworld")
    end

    it "preserves trailing-space hard line breaks when escape_hard_line_breaks is false (default)" do
      # Default config keeps trailing spaces; build_renderer must read .escape_hard_line_breaks,
      # not the Configuration object itself (which is always truthy)
      result = described_class.bbcode_to_markdown("hello  \nworld")
      expect(result).to eq("hello  \nworld")
    end

    it "uses the provided tag library to render" do
      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, fixed_output_tag.new("BOLDED"))

      expect(described_class.bbcode_to_markdown("[b]hi[/b]", tag_library: library)).to eq("BOLDED")
    end

    it "uses Markbridge.default_tag_library when tag_library not provided" do
      # Customize the shared default library; output must reflect the customization
      described_class.default_tag_library.register(
        Markbridge::AST::Bold,
        fixed_output_tag.new("OUTPUT_FROM_CUSTOMIZED_DEFAULT"),
      )

      expect(described_class.bbcode_to_markdown("[b]hi[/b]")).to eq(
        "OUTPUT_FROM_CUSTOMIZED_DEFAULT",
      )
    end

    it "collapses three or more consecutive newlines to exactly two" do
      # BBCode -> markdown -> cleanup turns runs of blank lines into a single blank line
      expect(described_class.bbcode_to_markdown("a\n\n\n\nb")).to eq("a\n\nb")
    end

    it "removes whitespace-only lines" do
      expect(described_class.bbcode_to_markdown("a\n   \nb")).to eq("a\n\nb")
    end

    it "strips leading and trailing whitespace from the final output" do
      expect(described_class.bbcode_to_markdown("   hi   ")).to eq("hi")
    end
  end

  describe ".parse_html" do
    it "returns an AST::Document" do
      expect(described_class.parse_html("<b>hi</b>")).to be_a(Markbridge::AST::Document)
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.parse_html(nil) }.to raise_error(
        ArgumentError,
        /input cannot be nil/,
      )
    end

    it "uses Markbridge.default_html_handlers when handlers not provided" do
      # Register a custom handler on the shared default registry
      described_class.default_html_handlers.register(
        "b",
        Markbridge::Parsers::HTML::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      doc = described_class.parse_html("<b>hi</b>")

      expect(doc.children.first).to be_a(Markbridge::AST::Italic)
    end
  end

  describe ".html_to_markdown" do
    it "renders HTML to markdown" do
      expect(described_class.html_to_markdown("<b>hi</b>")).to eq("**hi**")
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

      # With a custom registry mapping <b> to italic, the markdown output uses *_*
      expect(described_class.html_to_markdown("<b>hi</b>", handlers: registry)).to eq("*hi*")
    end

    it "uses the provided tag library to render" do
      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, fixed_output_tag.new("BOLDED"))

      expect(described_class.html_to_markdown("<b>hi</b>", tag_library: library)).to eq("BOLDED")
    end
  end

  describe ".parse_text_formatter_xml" do
    let(:xml) { "<r><B><s>[b]</s>hi<e>[/b]</e></B></r>" }

    it "returns an AST::Document" do
      expect(described_class.parse_text_formatter_xml(xml)).to be_a(Markbridge::AST::Document)
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.parse_text_formatter_xml(nil) }.to raise_error(
        ArgumentError,
        /input cannot be nil/,
      )
    end

    it "uses Markbridge.default_text_formatter_handlers when handlers not provided" do
      # Register a custom handler on the shared default registry; it must be
      # picked up by parse_text_formatter_xml (proves the default is reused)
      described_class.default_text_formatter_handlers.register(
        "B",
        Markbridge::Parsers::TextFormatter::Handlers::SimpleHandler.new(Markbridge::AST::Italic),
      )

      doc = described_class.parse_text_formatter_xml(xml)

      expect(doc.children.first).to be_a(Markbridge::AST::Italic)
    end
  end

  describe ".text_formatter_xml_to_markdown" do
    let(:xml) { "<r><B><s>[b]</s>hi<e>[/b]</e></B></r>" }

    it "renders TextFormatter XML to markdown" do
      expect(described_class.text_formatter_xml_to_markdown(xml)).to eq("**hi**")
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

      expect(described_class.text_formatter_xml_to_markdown(xml, handlers: registry)).to eq("*hi*")
    end

    it "uses the provided tag library to render" do
      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, fixed_output_tag.new("BOLDED"))

      expect(described_class.text_formatter_xml_to_markdown(xml, tag_library: library)).to eq(
        "BOLDED",
      )
    end
  end

  describe ".parse_mediawiki" do
    it "returns an AST::Document" do
      expect(described_class.parse_mediawiki("'''hi'''")).to be_a(Markbridge::AST::Document)
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.parse_mediawiki(nil) }.to raise_error(
        ArgumentError,
        /input cannot be nil/,
      )
    end

    it "coerces non-string input via to_s" do
      expect(described_class.parse_mediawiki(123)).to be_a(Markbridge::AST::Document)
    end
  end

  describe ".mediawiki_to_markdown" do
    it "renders MediaWiki to markdown" do
      expect(described_class.mediawiki_to_markdown("'''hi'''")).to eq("**hi**")
    end

    it "raises ArgumentError on nil input" do
      expect { described_class.mediawiki_to_markdown(nil) }.to raise_error(ArgumentError)
    end

    it "uses the provided tag library to render" do
      library = Markbridge::Renderers::Discourse::TagLibrary.new
      library.register(Markbridge::AST::Bold, fixed_output_tag.new("BOLDED"))

      expect(described_class.mediawiki_to_markdown("'''hi'''", tag_library: library)).to eq(
        "BOLDED",
      )
    end
  end

  describe "cleanup behavior in *_to_markdown methods" do
    it "removes whitespace-only lines (preserving multiple of them)" do
      # gsub vs sub: with sub only the first occurrence is replaced; gsub catches them all
      expect(described_class.bbcode_to_markdown("a\n   \nb\n\t\nc")).to eq("a\n\nb\n\nc")
    end

    it "collapses every run of 3+ newlines, not just the first" do
      # Two distinct runs of 3+ newlines must both be reduced
      expect(described_class.bbcode_to_markdown("a\n\n\nb\n\n\nc")).to eq("a\n\nb\n\nc")
    end

    it "preserves paragraph breaks (single blank line) without collapsing" do
      expect(described_class.bbcode_to_markdown("a\n\nb")).to eq("a\n\nb")
    end
  end

  describe ".parse_mediawiki coercion" do
    it "calls to_s on the input (not on Markbridge itself)" do
      wrapper = StringWrapper.new("'''hi'''")

      doc = described_class.parse_mediawiki(wrapper)

      # If `input.to_s` were replaced with `self.to_s`, the parsed document would
      # contain the literal text "Markbridge" instead of a Bold inside a Paragraph
      expect(doc.children.first).to be_a(Markbridge::AST::Paragraph)
      expect(doc.children.first.children.first).to be_a(Markbridge::AST::Bold)
    end
  end

  class StringWrapper
    def initialize(s) = @s = s
    def to_s = @s
  end
end
