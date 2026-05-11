# frozen_string_literal: true

require_relative "markbridge/version"
require_relative "markbridge/configuration"

require_relative "markbridge/ast"
require_relative "markbridge/renderers/discourse"
require_relative "markbridge/processors"

module Markbridge
  class << self
    # Parse BBCode to AST
    # @param input [String] BBCode source
    # @param handlers [HandlerRegistry, nil] custom handler registry or use default
    # @return [AST::Document]
    def parse_bbcode(input, handlers: nil)
      handlers ||= default_handlers
      parse_with(Parsers::BBCode::Parser, input, handlers:)
    end

    # Convert BBCode to Discourse Markdown
    # @param input [String] BBCode source
    # @param handlers [HandlerRegistry, nil] custom handler registry or use default
    # @param tag_library [TagLibrary, nil] custom tag library or use default
    # @return [String] Markdown output
    def bbcode_to_markdown(input, handlers: nil, tag_library: nil)
      ast = parse_bbcode(input, handlers:)
      render_to_markdown(ast, tag_library:)
    end

    # Parse HTML to AST
    # @param input [String] HTML source
    # @param handlers [HandlerRegistry, nil] custom handler registry or use default
    # @return [AST::Document]
    def parse_html(input, handlers: nil)
      handlers ||= default_html_handlers
      parse_with(Parsers::HTML::Parser, input, handlers:)
    end

    # Convert HTML to Discourse Markdown
    # @param input [String] HTML source
    # @param handlers [HandlerRegistry, nil] custom handler registry or use default
    # @param tag_library [TagLibrary, nil] custom tag library or use default
    # @return [String] Markdown output
    def html_to_markdown(input, handlers: nil, tag_library: nil)
      ast = parse_html(input, handlers:)
      render_to_markdown(ast, tag_library:)
    end

    # Parse s9e/TextFormatter XML to AST
    # @param input [String] XML source in s9e/TextFormatter format
    # @param handlers [Parsers::TextFormatter::HandlerRegistry, nil] custom handler registry or use default
    # @return [AST::Document]
    def parse_text_formatter_xml(input, handlers: nil)
      handlers ||= default_text_formatter_handlers
      parse_with(Parsers::TextFormatter::Parser, input, handlers:)
    end

    # Convert s9e/TextFormatter XML to Discourse Markdown
    # @param input [String] XML source in s9e/TextFormatter format
    # @param handlers [Parsers::TextFormatter::HandlerRegistry, nil] custom handler registry or use default
    # @param tag_library [TagLibrary, nil] custom tag library or use default
    # @return [String] Markdown output
    def text_formatter_xml_to_markdown(input, handlers: nil, tag_library: nil)
      ast = parse_text_formatter_xml(input, handlers:)
      render_to_markdown(ast, tag_library:)
    end

    # Parse MediaWiki wikitext to AST
    # @param input [String] MediaWiki source
    # @param inline_tag_registry [Parsers::MediaWiki::InlineTagRegistry, nil] custom registry
    # @return [AST::Document]
    def parse_mediawiki(input, inline_tag_registry: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      input = input.to_s
      parser = Parsers::MediaWiki::Parser.new(inline_tag_registry:)
      parser.parse(input)
    end

    # Convert MediaWiki wikitext to Discourse Markdown
    # @param input [String] MediaWiki source
    # @param inline_tag_registry [Parsers::MediaWiki::InlineTagRegistry, nil] custom registry
    # @param tag_library [TagLibrary, nil] custom tag library or use default
    # @return [String] Markdown output
    def mediawiki_to_markdown(input, inline_tag_registry: nil, tag_library: nil)
      ast = parse_mediawiki(input, inline_tag_registry:)
      render_to_markdown(ast, tag_library:)
    end

    # Get default handler registry
    # @return [Parsers::BBCode::HandlerRegistry]
    def default_handlers
      @default_handlers ||= Parsers::BBCode::HandlerRegistry.default
    end

    # Get default HTML handler registry
    # @return [Parsers::HTML::HandlerRegistry]
    def default_html_handlers
      @default_html_handlers ||= Parsers::HTML::HandlerRegistry.default
    end

    # Get default tag library
    # @return [Renderers::Discourse::TagLibrary]
    def default_tag_library
      @default_tag_library ||= Renderers::Discourse::TagLibrary.default
    end

    # Get default s9e/TextFormatter handler registry
    # @return [Parsers::TextFormatter::HandlerRegistry]
    def default_text_formatter_handlers
      @default_text_formatter_handlers ||= Parsers::TextFormatter::HandlerRegistry.default
    end

    # Get the global configuration
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure Markbridge with a block
    # @yield [Configuration]
    def configure
      yield configuration
    end

    # Reset defaults (useful for testing)
    def reset_defaults!
      @default_handlers = nil
      @default_html_handlers = nil
      @default_tag_library = nil
      @default_text_formatter_handlers = nil
      @configuration = nil
    end

    private

    def parse_with(parser_class, input, handlers:)
      raise ArgumentError, "input cannot be nil" if input.nil?

      parser = parser_class.new(handlers:)
      parser.parse(input.to_s)
    end

    def render_to_markdown(ast, tag_library:)
      tag_library ||= default_tag_library
      renderer = build_renderer(tag_library:)
      cleanup_markdown(renderer.render(ast))
    end

    def build_renderer(tag_library:)
      escaper =
        Renderers::Discourse::MarkdownEscaper.new(
          escape_hard_line_breaks: configuration.escape_hard_line_breaks,
        )
      Renderers::Discourse::Renderer.new(tag_library:, escaper:)
    end

    # Trailing-invisibles set: NBSP (U+00A0) plus the zero-width format
    # chars that render as nothing — ZWSP U+200B, ZWNJ U+200C, ZWJ U+200D,
    # WJ U+2060, ZWNBSP/BOM U+FEFF. Deliberately excludes ASCII space
    # and tab so Markdown's "two trailing spaces = hard line break" rule
    # still works. The `$` anchors to end-of-line (default Ruby regex
    # mode), so this strips per line without consuming the line break.
    TRAILING_INVISIBLE_RE = /[ ​‌‍⁠﻿]+$/
    private_constant :TRAILING_INVISIBLE_RE

    def cleanup_markdown(text)
      text
        .gsub(TRAILING_INVISIBLE_RE, "") # Strip trailing invisible chars at each line end
        .gsub(/\n{3,}/, "\n\n") # Max 2 consecutive newlines
        .gsub(/^[ \t]+$/, "") # Remove whitespace-only lines
        .strip # Trim leading/trailing whitespace
    end
  end
end
