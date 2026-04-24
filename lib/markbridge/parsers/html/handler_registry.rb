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
            registry.register(
              "br",
              lambda do |element:, parent:|
                parent << AST::LineBreak.new
                nil
              end,
            )
            registry.register(
              "hr",
              lambda do |element:, parent:|
                parent << AST::HorizontalRule.new
                nil
              end,
            )
            registry.register(%w[ul ol], Handlers::ListHandler.new)
            registry.register("li", Handlers::ListItemHandler.new)
            registry.register("table", Handlers::TableHandler.new)
            registry.register("tr", Handlers::TableRowHandler.new)
            registry.register(%w[td th], Handlers::TableCellHandler.new)
            registry.register("p", Handlers::ParagraphHandler.new)
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
