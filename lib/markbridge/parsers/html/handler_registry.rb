# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      # Registry of HTML tag handlers
      class HandlerRegistry
        def initialize
          @handlers = {}
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
          registry = new

          # Simple formatting handlers
          registry.register(%w[b strong], Handlers::SimpleHandler.new(AST::Bold))
          registry.register(%w[i em], Handlers::SimpleHandler.new(AST::Italic))
          registry.register(%w[s strike del], Handlers::SimpleHandler.new(AST::Strikethrough))
          registry.register("u", Handlers::SimpleHandler.new(AST::Underline))
          registry.register("sup", Handlers::SimpleHandler.new(AST::Superscript))
          registry.register("sub", Handlers::SimpleHandler.new(AST::Subscript))

          # Code handlers (raw content)
          registry.register(%w[code pre tt], Handlers::RawHandler.new(AST::Code))

          # Link and image handlers
          registry.register("a", Handlers::UrlHandler.new)
          registry.register("img", Handlers::ImageHandler.new)

          # Blockquote handler
          registry.register("blockquote", Handlers::QuoteHandler.new)

          # Void elements - use simple inline handlers
          registry.register(
            "br",
            lambda do |element:, parent:|
              parent << AST::LineBreak.new
              nil # Return nil - void element, no children
            end,
          )
          registry.register(
            "hr",
            lambda do |element:, parent:|
              parent << AST::HorizontalRule.new
              nil # Return nil - void element, no children
            end,
          )

          # List handlers
          registry.register(%w[ul ol], Handlers::ListHandler.new)
          registry.register("li", Handlers::ListItemHandler.new)

          # Table handlers (thead/tbody/tfoot are transparent - unregistered tags pass through)
          registry.register("table", Handlers::TableHandler.new)
          registry.register("tr", Handlers::TableRowHandler.new)
          registry.register(%w[td th], Handlers::TableCellHandler.new)

          # Paragraph handler (transparent - doesn't create AST node)
          registry.register("p", Handlers::ParagraphHandler.new)

          registry
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
