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
    # @param renderer [Renderers::Discourse::Renderer, nil] custom renderer
    #   (build with {.discourse_renderer}); defaults to a fresh default Renderer
    # @return [Conversion]
    def bbcode_to_markdown(input, handlers: nil, renderer: nil)
      parse = parse_bbcode(input, handlers:)
      build_conversion(parse, renderer:)
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
    # @param renderer [Renderers::Discourse::Renderer, nil] custom renderer
    # @return [Conversion]
    def html_to_markdown(input, handlers: nil, renderer: nil)
      parse = parse_html(input, handlers:)
      build_conversion(parse, renderer:)
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
    # @param renderer [Renderers::Discourse::Renderer, nil] custom renderer
    # @return [Conversion]
    def text_formatter_xml_to_markdown(input, handlers: nil, renderer: nil)
      parse = parse_text_formatter_xml(input, handlers:)
      build_conversion(parse, renderer:)
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

      Parse.new(ast:, format: :mediawiki, unknown_tags: parser.unknown_tags.dup, diagnostics: {})
    end

    # Convert MediaWiki wikitext to Discourse Markdown.
    #
    # @param input [String] MediaWiki source
    # @param handlers [Parsers::MediaWiki::InlineTagRegistry, nil]
    # @param renderer [Renderers::Discourse::Renderer, nil] custom renderer
    # @return [Conversion]
    def mediawiki_to_markdown(input, handlers: nil, renderer: nil)
      parse = parse_mediawiki(input, handlers:)
      build_conversion(parse, renderer:)
    end

    # Convert input in the given format. Thin dispatcher over the
    # four +*_to_markdown+ methods; useful when the format is data-
    # driven (e.g. iterating posts whose +:format+ column varies).
    #
    # @param input [String]
    # @param format [Symbol] one of +:bbcode+, +:html+,
    #   +:text_formatter_xml+, +:mediawiki+
    # @param kwargs [Hash] forwarded to the underlying convenience method
    #   (e.g. +handlers:+, +renderer:+, +raise_on_error:+).
    # @return [Conversion]
    def convert(input, format:, **kwargs)
      case format
      when :bbcode
        bbcode_to_markdown(input, **kwargs)
      when :html
        html_to_markdown(input, **kwargs)
      when :text_formatter_xml
        text_formatter_xml_to_markdown(input, **kwargs)
      when :mediawiki
        mediawiki_to_markdown(input, **kwargs)
      else
        raise ArgumentError,
              "unknown format #{format.inspect} " \
                "(expected :bbcode, :html, :text_formatter_xml, or :mediawiki)"
      end
    end

    # Render an existing AST to Discourse Markdown. Useful when the
    # caller already has the AST in hand (e.g. modified after parsing,
    # or built programmatically).
    #
    # @param ast [AST::Node]
    # @param format [Symbol] :discourse (only renderer currently shipped)
    # @param renderer [Renderers::Discourse::Renderer, nil]
    # @return [Conversion]
    def render(ast, format: :discourse, renderer: nil)
      raise ArgumentError, "unknown render format #{format.inspect}" unless format == :discourse

      renderer ||= Renderers::Discourse::Renderer.new
      markdown = renderer.postprocessor.call(renderer.render(ast))

      Conversion.new(
        markdown:,
        ast:,
        format: :discourse,
        unknown_tags: {
        },
        diagnostics: {
        },
        emissions: renderer.emissions,
        errors: [],
      )
    end

    # Build a configured Discourse {Renderers::Discourse::Renderer}
    # for use with the +renderer:+ kwarg on the +*_to_markdown+
    # convenience methods.
    #
    # @param tags [Hash{Class => Tag, nil}, nil] mappings to merge on
    #   top of the default library; +nil+ values unregister the class.
    # @param tag_library [Renderers::Discourse::TagLibrary, nil] base
    #   library to start from. Defaults to a fresh {TagLibrary.default}.
    # @param unregister [Array<Class>, nil] AST classes to drop from
    #   the library so they fall through to +render_children+.
    # @param escaper [Renderers::Discourse::MarkdownEscaper, nil]
    # @param escape_hard_line_breaks [Boolean] sugar for
    #   +escaper: MarkdownEscaper.new(escape_hard_line_breaks: true)+
    #   when no explicit +escaper:+ is given.
    # @return [Renderers::Discourse::Renderer]
    def discourse_renderer(
      tags: nil,
      tag_library: nil,
      unregister: nil,
      escaper: nil,
      escape_hard_line_breaks: false,
      postprocessor: nil
    )
      library = tag_library || Renderers::Discourse::TagLibrary.default
      library.merge(tags) if tags
      Array(unregister).each { |klass| library.unregister(klass) }

      escaper ||= Renderers::Discourse::MarkdownEscaper.new(escape_hard_line_breaks:)

      Renderers::Discourse::Renderer.new(tag_library: library, escaper:, postprocessor:)
    end

    private

    def bbcode_diagnostics(parser)
      {
        auto_closed_tags_count: parser.auto_closed_tags_count,
        depth_exceeded_count: parser.depth_exceeded_count,
        unclosed_raw_tags: parser.unclosed_raw_tags.dup,
      }
    end

    def build_conversion(parse, renderer: nil)
      renderer ||= Renderers::Discourse::Renderer.new
      markdown = renderer.postprocessor.call(renderer.render(parse.ast))

      Conversion.new(
        markdown:,
        ast: parse.ast,
        format: parse.format,
        unknown_tags: parse.unknown_tags,
        diagnostics: parse.diagnostics,
        emissions: renderer.emissions,
        errors: [],
      )
    end
  end
end
