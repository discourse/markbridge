# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      # Registry of HTML tag handlers and per-tag-name parser configuration.
      #
      # Handlers map a tag name to a handler instance. `block_level_tags` and
      # `whitespace_preserving_tags` configure parser whitespace behavior by
      # tag name, independent of whether a handler is registered — so unknown
      # tags like <div> or <section> still trigger boundary collapsing and
      # <pre>/<code> still pass through verbatim. Both sets are mutable, so
      # downstream consumers can add or remove tags freely:
      #
      #     registry = HandlerRegistry.default
      #     registry.block_level_tags << "my-block"
      #     registry.whitespace_preserving_tags.delete("tt")
      class HandlerRegistry
        # HTML5 block-level elements (per MDN). The trim-before-block rule
        # applies to these regardless of whether a handler is registered.
        DEFAULT_BLOCK_LEVEL_TAGS = %w[
          address
          article
          aside
          blockquote
          canvas
          dd
          details
          dialog
          div
          dl
          dt
          fieldset
          figcaption
          figure
          footer
          form
          h1
          h2
          h3
          h4
          h5
          h6
          header
          hgroup
          hr
          html
          li
          main
          nav
          noscript
          ol
          output
          p
          pre
          section
          table
          tbody
          td
          tfoot
          th
          thead
          tr
          ul
          video
        ].freeze

        # Tags whose default CSS preserves source whitespace
        # (`white-space: pre*`). Text inside these is passed through
        # verbatim; outside, `\s+` runs collapse to a single space.
        DEFAULT_WHITESPACE_PRESERVING_TAGS = %w[pre code textarea tt].freeze

        # @return [Set<String>] mutable set of tag names treated as block-level.
        attr_reader :block_level_tags

        # @return [Set<String>] mutable set of tag names whose contents
        #   preserve source whitespace.
        attr_reader :whitespace_preserving_tags

        def initialize
          @handlers = {}
          @block_level_tags = Set.new(DEFAULT_BLOCK_LEVEL_TAGS)
          @whitespace_preserving_tags = Set.new(DEFAULT_WHITESPACE_PRESERVING_TAGS)
        end

        # Register a handler for one or more tag names
        # @param tag_names [String, Array<String>] tag name(s) to register
        # @param handler [BaseHandler, Proc] the handler instance or proc
        def register(tag_names, handler)
          Array(tag_names).each { |tag_name| @handlers[tag_name.to_s.downcase] = handler }
          self
        end

        # Get handler for a tag name
        # @param tag_name [String]
        # @return [BaseHandler, Proc, nil]
        def [](tag_name)
          @handlers[tag_name.to_s.downcase]
        end

        # Create the default handler registry with common HTML tags
        # @return [HandlerRegistry]
        def self.default
          new.tap do |registry|
            registry.register(%w[b strong], Handlers::SimpleHandler.new(AST::Bold))
            registry.register(%w[i em], Handlers::SimpleHandler.new(AST::Italic))
            registry.register(%w[s strike del], Handlers::SimpleHandler.new(AST::Strikethrough))
            registry.register("u", Handlers::SimpleHandler.new(AST::Underline))
            registry.register("sup", Handlers::SimpleHandler.new(AST::Superscript))
            registry.register("sub", Handlers::SimpleHandler.new(AST::Subscript))
            registry.register(%w[code pre tt], Handlers::RawHandler.new(AST::Code))
            registry.register("a", Handlers::UrlHandler.new)
            registry.register("img", Handlers::ImageHandler.new)
            registry.register("blockquote", Handlers::QuoteHandler.new)
            registry.register("br", Handlers::VoidHandler.new(AST::LineBreak))
            registry.register("hr", Handlers::VoidHandler.new(AST::HorizontalRule))
            registry.register(%w[ul ol], Handlers::ListHandler.new)
            registry.register("li", Handlers::ListItemHandler.new)
            registry.register("table", Handlers::TableHandler.new)
            registry.register("tr", Handlers::TableRowHandler.new)
            registry.register(%w[td th], Handlers::TableCellHandler.new)
            registry.register("p", Handlers::ParagraphHandler.new)
            registry.register("span", Handlers::SpanHandler.new)
          end
        end

        # Build a registry from the default configuration with optional customization
        # @yield [HandlerRegistry] the registry to customize
        # @return [HandlerRegistry]
        def self.build_from_default
          registry = default
          yield(registry) if block_given?
          registry
        end
      end
    end
  end
end
