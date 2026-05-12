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

      parser = Parsers::BBCode::Parser.new(handlers:)
      ast = parser.parse(input.to_s)

      Parse.new(
        ast:,
        format: :bbcode,
        unknown_tags: parser.unknown_tags,
        diagnostics: bbcode_diagnostics(parser),
      )
    end

    # Convert BBCode to Discourse Markdown.
    #
    # If a block is given, it is called with the parsed AST between
    # parse and render — the caller can append/remove/replace nodes
    # before rendering. Mutations to the yielded AST persist in
    # {Conversion#ast}.
    #
    # @param input [String] BBCode source
    # @param handlers [Parsers::BBCode::HandlerRegistry, nil] custom handlers
    # @param renderer [Renderers::Discourse::Renderer, nil] custom renderer
    #   (build with {.discourse_renderer}); defaults to a fresh default Renderer
    # @param raise_on_error [Boolean] when true (default), let render-time
    #   exceptions propagate; when false, swallow them, return whatever
    #   the renderer produced before failing, and surface them via
    #   {Conversion#errors}.
    # @yieldparam ast [AST::Document] mutate before rendering (optional)
    # @return [Conversion]
    def bbcode_to_markdown(input, handlers: nil, renderer: nil, raise_on_error: true)
      parse = parse_bbcode(input, handlers:)
      yield(parse.ast) if block_given?
      build_conversion(parse, renderer:, raise_on_error:)
    end

    # Parse HTML to AST.
    #
    # @param input [String, Nokogiri::XML::Node] HTML source or
    #   pre-parsed Nokogiri tree (e.g. the +DocumentFragment+ returned
    #   by +Nokogiri::HTML.fragment+). Passing a pre-parsed tree lets
    #   callers run their own Nokogiri-driven pre-processing without
    #   forcing Markbridge to re-parse the same bytes.
    # @param handlers [Parsers::HTML::HandlerRegistry, nil] custom handlers
    # @return [Parse]
    def parse_html(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      parser = Parsers::HTML::Parser.new(handlers:)
      ast = parser.parse(input)

      Parse.new(ast:, format: :html, unknown_tags: parser.unknown_tags, diagnostics: {})
    end

    # Convert HTML to Discourse Markdown.
    #
    # @param input [String] HTML source
    # @param handlers [Parsers::HTML::HandlerRegistry, nil] custom handlers
    # @param renderer [Renderers::Discourse::Renderer, nil] custom renderer
    # @param raise_on_error [Boolean]
    # @yieldparam ast [AST::Document] mutate before rendering (optional)
    # @return [Conversion]
    def html_to_markdown(input, handlers: nil, renderer: nil, raise_on_error: true)
      parse = parse_html(input, handlers:)
      yield(parse.ast) if block_given?
      build_conversion(parse, renderer:, raise_on_error:)
    end

    # Parse s9e/TextFormatter XML to AST.
    #
    # @param input [String, Nokogiri::XML::Node] XML source or
    #   pre-parsed Nokogiri tree. A +Nokogiri::XML::Document+ is
    #   unwrapped via +#root+; any other node is treated as the root.
    # @param handlers [Parsers::TextFormatter::HandlerRegistry, nil] custom handlers
    # @return [Parse]
    def parse_text_formatter_xml(input, handlers: nil)
      raise ArgumentError, "input cannot be nil" if input.nil?

      parser = Parsers::TextFormatter::Parser.new(handlers:)
      ast = parser.parse(input)

      Parse.new(
        ast:,
        format: :text_formatter_xml,
        unknown_tags: parser.unknown_tags,
        diagnostics: {
        },
      )
    end

    # Convert s9e/TextFormatter XML to Discourse Markdown.
    #
    # @param input [String] XML source
    # @param handlers [Parsers::TextFormatter::HandlerRegistry, nil] custom handlers
    # @param renderer [Renderers::Discourse::Renderer, nil] custom renderer
    # @param raise_on_error [Boolean]
    # @yieldparam ast [AST::Document] mutate before rendering (optional)
    # @return [Conversion]
    def text_formatter_xml_to_markdown(input, handlers: nil, renderer: nil, raise_on_error: true)
      parse = parse_text_formatter_xml(input, handlers:)
      yield(parse.ast) if block_given?
      build_conversion(parse, renderer:, raise_on_error:)
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

      Parse.new(ast:, format: :mediawiki, unknown_tags: parser.unknown_tags, diagnostics: {})
    end

    # Convert MediaWiki wikitext to Discourse Markdown.
    #
    # @param input [String] MediaWiki source
    # @param handlers [Parsers::MediaWiki::InlineTagRegistry, nil]
    # @param renderer [Renderers::Discourse::Renderer, nil] custom renderer
    # @param raise_on_error [Boolean]
    # @yieldparam ast [AST::Document] mutate before rendering (optional)
    # @return [Conversion]
    def mediawiki_to_markdown(input, handlers: nil, renderer: nil, raise_on_error: true)
      parse = parse_mediawiki(input, handlers:)
      yield(parse.ast) if block_given?
      build_conversion(parse, renderer:, raise_on_error:)
    end

    # Convert input in the given format. Thin dispatcher over the
    # four +*_to_markdown+ methods; useful when the format is data-
    # driven (e.g. iterating posts whose +:format+ column varies).
    # An optional block is forwarded to the dispatched method.
    #
    # @param input [String]
    # @param format [Symbol] one of +:bbcode+, +:html+,
    #   +:text_formatter_xml+, +:mediawiki+
    # @param kwargs [Hash] forwarded to the underlying convenience method
    #   (e.g. +handlers:+, +renderer:+, +raise_on_error:+).
    # @yieldparam ast [AST::Document] mutate before rendering (optional)
    # @return [Conversion]
    def convert(input, format:, **kwargs, &block)
      case format
      when :bbcode
        bbcode_to_markdown(input, **kwargs, &block)
      when :html
        html_to_markdown(input, **kwargs, &block)
      when :text_formatter_xml
        text_formatter_xml_to_markdown(input, **kwargs, &block)
      when :mediawiki
        mediawiki_to_markdown(input, **kwargs, &block)
      else
        raise ArgumentError,
              "unknown format #{format.inspect} " \
                "(expected :bbcode, :html, :text_formatter_xml, or :mediawiki)"
      end
    end

    # Render a {Parse} or a bare AST node to Discourse Markdown.
    # Useful when the caller has mutated the AST between parse and
    # render (e.g. appending attachments not present in the source),
    # or built an AST programmatically.
    #
    # When given a {Parse}, the returned {Conversion} carries the
    # parser's +unknown_tags+, +diagnostics+, and source +format+
    # forward. When given an AST node, those fields default to empty
    # and +format+ falls back to +:discourse+.
    #
    # @param parse_or_ast [Parse, AST::Node]
    # @param format [Symbol] :discourse (only renderer currently shipped)
    # @param renderer [Renderers::Discourse::Renderer, nil]
    # @param raise_on_error [Boolean]
    # @return [Conversion]
    def render(parse_or_ast, format: :discourse, renderer: nil, raise_on_error: true)
      raise ArgumentError, "unknown render format #{format.inspect}" unless format == :discourse

      parse =
        case parse_or_ast
        when Parse
          parse_or_ast
        when AST::Node
          Parse.new(ast: parse_or_ast, format: :discourse, unknown_tags: {}, diagnostics: {})
        else
          raise ArgumentError, "expected Parse or AST::Node, got #{parse_or_ast.class}"
        end

      build_conversion(parse, renderer:, raise_on_error:)
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
    # @param escaper [#escape, nil] when given, used as-is; +escape:+,
    #   +escape_hard_line_breaks:+, and +allow:+ are then ignored.
    # @param escape [Boolean] when +false+, the renderer is built with
    #   {Renderers::Discourse::IdentityEscaper} (no Markdown escaping).
    #   Mutually exclusive with +escape_hard_line_breaks:+ / +allow:+.
    # @param escape_hard_line_breaks [Boolean] forwarded to a fresh
    #   {MarkdownEscaper} when no explicit +escaper:+ is given.
    # @param allow [Symbol, Array<Symbol>, nil] block-level constructs to
    #   pass through unescaped (e.g. +:lists+, +:bullet_list+,
    #   +:ordered_list+, +:atx_heading+, +:block_quote+); forwarded to a
    #   fresh {MarkdownEscaper}.
    # @param postprocessor [Renderers::Discourse::Postprocessor, nil] when given,
    #   used as-is; +strip_trailing_invisibles:+ is then ignored.
    # @param strip_trailing_invisibles [Boolean] forwarded to a fresh
    #   {Renderers::Discourse::Postprocessor} when no explicit
    #   +postprocessor:+ is given. Strips NBSP and zero-width format
    #   characters from the end of each line.
    # @return [Renderers::Discourse::Renderer]
    def discourse_renderer(
      tags: nil,
      tag_library: nil,
      unregister: nil,
      escaper: nil,
      escape: true,
      escape_hard_line_breaks: false,
      allow: nil,
      postprocessor: nil,
      strip_trailing_invisibles: false
    )
      library = tag_library || Renderers::Discourse::TagLibrary.default
      library.merge(tags) if tags
      Array(unregister).each { |klass| library.unregister(klass) }

      escaper ||= build_escaper(escape:, escape_hard_line_breaks:, allow:)
      postprocessor ||= Renderers::Discourse::Postprocessor.new(strip_trailing_invisibles:)

      Renderers::Discourse::Renderer.new(tag_library: library, escaper:, postprocessor:)
    end

    private

    def bbcode_diagnostics(parser)
      {
        auto_closed_tags_count: parser.auto_closed_tags_count,
        depth_exceeded_count: parser.depth_exceeded_count,
        unclosed_raw_tags: parser.unclosed_raw_tags,
      }
    end

    def build_conversion(parse, renderer:, raise_on_error:)
      renderer ||= Renderers::Discourse::Renderer.new
      markdown, errors = render_through(renderer, parse.ast, raise_on_error:)

      Conversion.new(
        markdown:,
        ast: parse.ast,
        format: parse.format,
        unknown_tags: parse.unknown_tags,
        diagnostics: parse.diagnostics,
        errors:,
      )
    end

    def build_escaper(escape:, escape_hard_line_breaks:, allow:)
      if escape == false
        if escape_hard_line_breaks || allow
          raise ArgumentError,
                "escape: false is mutually exclusive with " \
                  "escape_hard_line_breaks: / allow: (those configure " \
                  "MarkdownEscaper, which escape: false replaces wholesale)"
        end
        Renderers::Discourse::IdentityEscaper.new
      else
        Renderers::Discourse::MarkdownEscaper.new(escape_hard_line_breaks:, allow:)
      end
    end

    def render_through(renderer, ast, raise_on_error:)
      raw = renderer.render(ast)
      [renderer.postprocessor.call(raw), []]
    rescue StandardError => e
      raise if raise_on_error
      ["", [e]]
    end
  end
end
