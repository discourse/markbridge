# frozen_string_literal: true

require_relative "markbridge/version"
require_relative "markbridge/parse"
require_relative "markbridge/conversion"

require_relative "markbridge/ast"
require_relative "markbridge/renderers/discourse"
require_relative "markbridge/processors"

module Markbridge
  class << self
    # Parse BBCode to AST.
    #
    # @param input [String] BBCode source
    # @param handlers [Parsers::BBCode::HandlerRegistry, nil] custom handlers (defaults to .default)
    # @return [Parse]
    def parse_bbcode(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      handlers ||= Parsers::BBCode::HandlerRegistry.default
      parser = Parsers::BBCode::Parser.new(handlers:)
      ast = parser.parse(input.to_s)

      Parse.new(
        ast:,
        format: :bbcode,
        unknown_tags: parser.unknown_tags.dup,
        diagnostics: bbcode_diagnostics(parser),
      )
    end

    # Convert BBCode to Discourse Markdown.
    #
    # @param input [String] BBCode source
    # @param handlers [Parsers::BBCode::HandlerRegistry, nil] custom handlers
    # @return [Conversion]
    def bbcode_to_markdown(input, handlers: nil)
      parse = parse_bbcode(input, handlers:)
      build_conversion(parse)
    end

    # Parse HTML to AST.
    #
    # @param input [String] HTML source
    # @param handlers [Parsers::HTML::HandlerRegistry, nil] custom handlers
    # @return [Parse]
    def parse_html(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      handlers ||= Parsers::HTML::HandlerRegistry.default
      parser = Parsers::HTML::Parser.new(handlers:)
      ast = parser.parse(input.to_s)

      Parse.new(ast:, format: :html, unknown_tags: parser.unknown_tags.dup, diagnostics: {})
    end

    # Convert HTML to Discourse Markdown.
    #
    # @param input [String] HTML source
    # @param handlers [Parsers::HTML::HandlerRegistry, nil] custom handlers
    # @return [Conversion]
    def html_to_markdown(input, handlers: nil)
      parse = parse_html(input, handlers:)
      build_conversion(parse)
    end

    # Parse s9e/TextFormatter XML to AST.
    #
    # @param input [String] XML source
    # @param handlers [Parsers::TextFormatter::HandlerRegistry, nil] custom handlers
    # @return [Parse]
    def parse_text_formatter_xml(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      handlers ||= Parsers::TextFormatter::HandlerRegistry.default
      parser = Parsers::TextFormatter::Parser.new(handlers:)
      ast = parser.parse(input.to_s)

      Parse.new(
        ast:,
        format: :text_formatter_xml,
        unknown_tags: parser.unknown_tags.dup,
        diagnostics: {
        },
      )
    end

    # Convert s9e/TextFormatter XML to Discourse Markdown.
    #
    # @param input [String] XML source
    # @param handlers [Parsers::TextFormatter::HandlerRegistry, nil] custom handlers
    # @return [Conversion]
    def text_formatter_xml_to_markdown(input, handlers: nil)
      parse = parse_text_formatter_xml(input, handlers:)
      build_conversion(parse)
    end

    # Parse MediaWiki wikitext to AST.
    #
    # @param input [String] MediaWiki source
    # @param handlers [Parsers::MediaWiki::InlineTagRegistry, nil] custom inline-tag registry
    # @return [Parse]
    def parse_mediawiki(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      parser = Parsers::MediaWiki::Parser.new(handlers:)
      ast = parser.parse(input.to_s)

      Parse.new(ast:, format: :mediawiki, unknown_tags: {}, diagnostics: {})
    end

    # Convert MediaWiki wikitext to Discourse Markdown.
    #
    # @param input [String] MediaWiki source
    # @param handlers [Parsers::MediaWiki::InlineTagRegistry, nil]
    # @return [Conversion]
    def mediawiki_to_markdown(input, handlers: nil)
      parse = parse_mediawiki(input, handlers:)
      build_conversion(parse)
    end

    private

    def bbcode_diagnostics(parser)
      {
        auto_closed_tags_count: parser.auto_closed_tags_count,
        depth_exceeded_count: parser.depth_exceeded_count,
        unclosed_raw_tags: parser.unclosed_raw_tags.dup,
      }
    end

    def build_conversion(parse)
      renderer = Renderers::Discourse::Renderer.new
      markdown = cleanup_markdown(renderer.render(parse.ast))

      Conversion.new(
        markdown:,
        ast: parse.ast,
        format: parse.format,
        unknown_tags: parse.unknown_tags,
        diagnostics: parse.diagnostics,
        emissions: {
        },
        errors: [],
      )
    end

    def cleanup_markdown(text)
      text
        .gsub(/\n{3,}/, "\n\n") # Max 2 consecutive newlines
        .gsub(/^[ \t]+$/, "") # Remove whitespace-only lines
        .strip # Trim leading/trailing whitespace
    end
  end
end
