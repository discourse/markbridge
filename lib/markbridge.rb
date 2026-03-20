# frozen_string_literal: true

require_relative "markbridge/version"
require_relative "markbridge/configuration"

require_relative "markbridge/ast"
require_relative "markbridge/renderers/discourse"
require_relative "markbridge/parsers/media_wiki"
require_relative "markbridge/parsers/text_formatter"
require_relative "markbridge/processors"

module Markbridge
  class << self
    # Parse BBCode to AST
    # @param input [String] BBCode source
    # @param handlers [HandlerRegistry, nil] custom handler registry or use default
    # @return [AST::Document]
    def parse_bbcode(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      input = input.to_s # Coerce to string
      handlers ||= default_handlers

      parser = Parsers::BBCode::Parser.new(handlers:)
      parser.parse(input)
    end

    # Convert BBCode to Discourse Markdown
    # @param input [String] BBCode source
    # @param handlers [HandlerRegistry, nil] custom handler registry or use default
    # @param tag_library [TagLibrary, nil] custom tag library or use default
    # @return [String] Markdown output
    def bbcode_to_markdown(input, handlers: nil, tag_library: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      handlers ||= default_handlers
      tag_library ||= default_tag_library

      ast = parse_bbcode(input, handlers:)
      renderer = build_renderer(tag_library:)

      # Clean up output
      result = renderer.render(ast)
      cleanup_markdown(result)
    end

    # Parse HTML to AST
    # @param input [String] HTML source
    # @param handlers [HandlerRegistry, nil] custom handler registry or use default
    # @return [AST::Document]
    def parse_html(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      input = input.to_s # Coerce to string
      handlers ||= default_html_handlers

      parser = Parsers::HTML::Parser.new(handlers:)
      parser.parse(input)
    end

    # Convert HTML to Discourse Markdown
    # @param input [String] HTML source
    # @param handlers [HandlerRegistry, nil] custom handler registry or use default
    # @param tag_library [TagLibrary, nil] custom tag library or use default
    # @return [String] Markdown output
    def html_to_markdown(input, handlers: nil, tag_library: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      handlers ||= default_html_handlers
      tag_library ||= default_tag_library

      ast = parse_html(input, handlers:)
      renderer = build_renderer(tag_library:)

      # Clean up output
      result = renderer.render(ast)
      cleanup_markdown(result)
    end

    # Parse s9e/TextFormatter XML to AST
    # @param input [String] XML source in s9e/TextFormatter format
    # @param handlers [Parsers::TextFormatter::HandlerRegistry, nil] custom handler registry or use default
    # @return [AST::Document]
    def parse_text_formatter_xml(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      input = input.to_s
      handlers ||= default_text_formatter_handlers

      parser = Parsers::TextFormatter::Parser.new(handlers:)
      parser.parse(input)
    end

    # Convert s9e/TextFormatter XML to Discourse Markdown
    # @param input [String] XML source in s9e/TextFormatter format
    # @param handlers [Parsers::TextFormatter::HandlerRegistry, nil] custom handler registry or use default
    # @param tag_library [TagLibrary, nil] custom tag library or use default
    # @return [String] Markdown output
    def text_formatter_xml_to_markdown(input, handlers: nil, tag_library: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      handlers ||= default_text_formatter_handlers
      tag_library ||= default_tag_library

      ast = parse_text_formatter_xml(input, handlers:)
      renderer = build_renderer(tag_library:)

      result = renderer.render(ast)
      cleanup_markdown(result)
    end

    # Parse MediaWiki wikitext to AST
    # @param input [String] MediaWiki source
    # @return [AST::Document]
    def parse_mediawiki(input)
      raise ArgumentError, "input cannot be nil" if input.nil?

      input = input.to_s
      parser = Parsers::MediaWiki::Parser.new
      parser.parse(input)
    end

    # Convert MediaWiki wikitext to Discourse Markdown
    # @param input [String] MediaWiki source
    # @param tag_library [TagLibrary, nil] custom tag library or use default
    # @return [String] Markdown output
    def mediawiki_to_markdown(input, tag_library: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      tag_library ||= default_tag_library

      ast = parse_mediawiki(input)
      renderer = build_renderer(tag_library:)

      result = renderer.render(ast)
      cleanup_markdown(result)
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

    def build_renderer(tag_library:)
      escaper =
        Renderers::Discourse::MarkdownEscaper.new(
          escape_hard_line_breaks: configuration.escape_hard_line_breaks,
        )
      Renderers::Discourse::Renderer.new(tag_library:, escaper:)
    end

    def cleanup_markdown(text)
      text
        .gsub(/\n{3,}/, "\n\n") # Max 2 consecutive newlines
        .gsub(/^[ \t]+$/m, "") # Remove whitespace-only lines
        .strip # Trim leading/trailing whitespace
    end
  end
end
