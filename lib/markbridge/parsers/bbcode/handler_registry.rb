# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Registry of BBCode tag handlers
      class HandlerRegistry
        include Enumerable

        attr_writer :closing_strategy

        def initialize(closing_strategy: nil)
          @handlers = {}
          @element_handlers = {}
          @auto_closeable_elements = Set.new
          @closing_strategy = closing_strategy
        end

        # Iterate over registered (tag_name, handler) pairs.
        # Useful for debugging custom registries — e.g. confirming an override
        # has stuck. Iteration order matches registration order.
        # @yieldparam tag_name [String]
        # @yieldparam handler [BaseHandler]
        # @return [Enumerator] when no block is given
        def each(&block)
          @handlers.each(&block)
        end

        # Register a handler for one or more tag names and associate it with an element class
        # @param tag_names [String, Array<String>] tag name(s) to register
        # @param handler [BaseHandler] the handler instance
        def register(tag_names, handler)
          element_class = handler.element_class
          Array(tag_names).each { |tag_name| @handlers[tag_name.to_s.downcase] = handler }
          @element_handlers[element_class] = handler
          @auto_closeable_elements << element_class if handler.auto_closeable?
          self
        end

        # Replace the handler bound to one or more tag names by yielding
        # the previously-bound handler (which may be +nil+) and
        # registering whatever the block returns. Used to install a
        # delegating handler that wraps the default.
        #
        # @example Wrap the default URL handler
        #   registry.overlay(%w[url link iurl]) do |default|
        #     LinkifyingUrlHandler.new(default:)
        #   end
        #
        # @param tag_names [String, Array<String>]
        # @yieldparam previous [BaseHandler, nil] previously bound handler
        # @return [self]
        def overlay(tag_names)
          Array(tag_names).each do |name|
            previous = self[name]
            register(name, yield(previous))
          end
          self
        end

        # Get handler for a tag name
        # @param tag_name [String]
        # @return [BaseHandler, nil]
        def [](tag_name)
          @handlers[tag_name.to_s.downcase]
        end

        # Get handler for an element instance
        # @param element [Element]
        # @return [BaseHandler, nil]
        def handler_for_element(element)
          @element_handlers[element.class]
        end

        # Check if an element class is auto-closeable
        # @param element_class [Class]
        # @return [Boolean]
        def auto_closeable?(element_class)
          @auto_closeable_elements.include?(element_class)
        end

        # Close an element using the closing strategy
        # @param token [TagEndToken]
        # @param context [ParserState]
        # @param tokens [PeekableEnumerator, nil]
        def close_element(token:, context:, tokens: nil)
          @closing_strategy&.handle_close(token:, context:, registry: self, tokens:)
        end

        # Create the default handler registry with common BBCode tags.
        #
        # Each call returns a *fresh* instance — mutations made to one will
        # not be visible to another. Convenience methods on +Markbridge+
        # build a fresh default registry per call when none is supplied;
        # to share state across calls, build one once and pass it via
        # the +handlers:+ kwarg.
        #
        # @param closing_strategy [Object, nil] optional closing strategy to apply, defaults to Reordering strategy
        # @return [HandlerRegistry]
        def self.default(closing_strategy: nil)
          # Create registry - we'll set closing strategy after registering handlers
          registry = new

          # Simple formatting handlers (auto-closeable)
          registry.register(
            %w[b bold strong],
            Handlers::SimpleHandler.new(AST::Bold, auto_closeable: true),
          )
          registry.register(
            %w[i italic em],
            Handlers::SimpleHandler.new(AST::Italic, auto_closeable: true),
          )
          registry.register(
            %w[s strike del],
            Handlers::SimpleHandler.new(AST::Strikethrough, auto_closeable: true),
          )
          registry.register(
            %w[u underline],
            Handlers::SimpleHandler.new(AST::Underline, auto_closeable: true),
          )
          registry.register(
            "sup",
            Handlers::SimpleHandler.new(AST::Superscript, auto_closeable: true),
          )
          registry.register(
            "sub",
            Handlers::SimpleHandler.new(AST::Subscript, auto_closeable: true),
          )

          # Code handlers (raw content)
          registry.register(%w[code pre tt], Handlers::CodeHandler.new)

          # Image handler
          registry.register("img", Handlers::ImageHandler.new)

          # Attachment handler
          registry.register(%w[attach attachment], Handlers::AttachmentHandler.new)

          # URL handler
          registry.register(%w[url link iurl], Handlers::UrlHandler.new)

          # Email handler
          registry.register("email", Handlers::EmailHandler.new)

          # Quote handler
          registry.register("quote", Handlers::QuoteHandler.new)

          # Spoiler handler
          registry.register(%w[spoiler hide], Handlers::SpoilerHandler.new)

          # Color handler
          registry.register("color", Handlers::ColorHandler.new)

          # Size handler
          registry.register("size", Handlers::SizeHandler.new)

          # Alignment handlers (single instance - reads alignment from tag name)
          registry.register(%w[center left right justify], Handlers::AlignHandler.new)

          # Self-closing handlers
          registry.register("br", Handlers::SelfClosingHandler.new(AST::LineBreak))
          registry.register("hr", Handlers::SelfClosingHandler.new(AST::HorizontalRule))

          # List handlers
          registry.register(%w[list ul ol ulist olist], Handlers::ListHandler.new)
          registry.register(%w[* li .], Handlers::ListItemHandler.new)

          # Table handlers
          registry.register("table", Handlers::TableHandler.new)
          registry.register("tr", Handlers::TableRowHandler.new)
          registry.register(%w[td th], Handlers::TableCellHandler.new)

          # Set the closing strategy
          registry.closing_strategy = closing_strategy || default_closing_strategy(registry)

          registry
        end

        # Shared, deep-frozen default registry for the no-customization
        # fast path. Built once per process; {Parser} falls back to it
        # when no +handlers:+ are given, skipping the full registry
        # construction on every parse. Handlers and closing strategies
        # are stateless after construction, so sharing is safe across
        # parsers and threads.
        #
        # @return [HandlerRegistry] the same frozen instance on every call
        def self.shared_default
          @shared_default ||= default.freeze
        end

        # Freeze the registry together with its internal collections so
        # that registration on a shared instance fails loudly instead of
        # silently mutating state visible to every parser.
        def freeze
          @handlers.freeze
          @element_handlers.freeze
          @auto_closeable_elements.freeze
          super
        end

        # Build a registry from the default configuration with optional customization
        # @yield [HandlerRegistry] the registry to customize
        # @return [HandlerRegistry]
        def self.build_from_default
          registry = default
          yield(registry) if block_given?
          registry
        end

        # Create the default closing strategy for a registry
        # @param registry [HandlerRegistry] the registry to create a strategy for
        # @return [ClosingStrategies::Reordering]
        def self.default_closing_strategy(registry)
          reconciler = ClosingStrategies::TagReconciler.new(registry:)
          ClosingStrategies::Reordering.new(reconciler)
        end
      end
    end
  end
end
