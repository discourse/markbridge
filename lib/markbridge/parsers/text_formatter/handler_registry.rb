# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      # Registry of s9e/TextFormatter XML element handlers
      #
      # Manages mappings between XML element names and handler objects.
      # Handlers must respond to #process(element:, parent:) and return the created element
      # if children should be processed, or nil otherwise.
      #
      # @example Using default mappings
      #   registry = HandlerRegistry.default
      #   element = registry.process_element(xml_element, parent)
      #
      # @example Customizing mappings with handler objects
      #   registry = HandlerRegistry.build_from_default do |r|
      #     r.register("CUSTOM", MyCustomHandler.new)
      #     r.register("B", SimpleHandler.new(AST::Bold))  # Override default
      #   end
      #
      # @example Using lambdas for simple mappings
      #   registry = HandlerRegistry.new
      #   registry.register("CUSTOM", ->(element:, parent:) {
      #     node = AST::Custom.new
      #     parent << node
      #     node  # Return node to process children
      #   })
      class HandlerRegistry
        # Create a new registry with default mappings
        # @return [HandlerRegistry]
        def self.default
          new.tap(&:register_defaults)
        end

        # Build from default mappings with custom additions
        # @yield [HandlerRegistry] registry with default mappings loaded
        # @return [HandlerRegistry]
        def self.build_from_default
          default.tap { |registry| yield registry if block_given? }
        end

        def initialize
          @mappings = {}
        end

        # Register a handler for an element
        # @param element_name [String] XML element name (case-insensitive)
        # @param handler [#process, #call] Handler object or lambda
        # @example With handler object
        #   registry.register("CUSTOM", MyCustomHandler.new)
        # @example With lambda
        #   registry.register("CUSTOM", ->(element:, parent:) { ... })
        def register(element_name, handler)
          @mappings[element_name.upcase] = handler
        end

        # Check if a handler is registered for an element
        # @param element_name [String] XML element name
        # @return [Boolean] true if handler is registered
        def has_handler?(element_name)
          @mappings.key?(element_name.upcase)
        end

        # Process an XML element using the registered handler
        # @param element [Nokogiri::XML::Element]
        # @param parent [AST::Element] parent node to add children to
        # @return [AST::Element, nil] the created element if children should be processed, nil otherwise
        def process_element(element, parent)
          tag_name = element.name.upcase
          handler = @mappings[tag_name]
          return nil unless handler

          # Call handler and return its result (element or nil)
          if handler.respond_to?(:process)
            handler.process(element:, parent:)
          elsif handler.respond_to?(:call)
            handler.call(element:, parent:)
          else
            raise ArgumentError, "Handler must respond to :process or :call"
          end
        end

        # Register all default s9e/TextFormatter element mappings
        def register_defaults
          # Simple formatting elements
          register("B", Handlers::SimpleHandler.new(AST::Bold))
          register("I", Handlers::SimpleHandler.new(AST::Italic))
          register("U", Handlers::SimpleHandler.new(AST::Underline))
          register("S", Handlers::SimpleHandler.new(AST::Strikethrough))

          # Complex elements with attributes
          register("URL", Handlers::UrlHandler.new)
          register("EMAIL", Handlers::EmailHandler.new)
          register("CODE", Handlers::CodeHandler.new)
          register("QUOTE", Handlers::QuoteHandler.new)
          register("IMG", Handlers::ImageHandler.new)
          register("LIST", Handlers::ListHandler.new)
          register(
            "COLOR",
            Handlers::AttributeHandler.new(AST::Color, attribute: :color, param: :color),
          )
          register(
            "SIZE",
            Handlers::AttributeHandler.new(AST::Size, attribute: :size, param: :size),
          )
          register(
            "ALIGN",
            Handlers::AttributeHandler.new(AST::Align, attribute: :align, param: :alignment),
          )
          register(
            "SPOILER",
            Handlers::AttributeHandler.new(AST::Spoiler, attribute: :title, param: :title),
          )
          register("ATTACHMENT", Handlers::AttachmentHandler.new)
          register("ATTACH", Handlers::AttachmentHandler.new)

          # List item (supports both LI and * for compatibility)
          register("LI", Handlers::SimpleHandler.new(AST::ListItem))
          register("*", Handlers::SimpleHandler.new(AST::ListItem))

          # Paragraphs
          register("P", Handlers::SimpleHandler.new(AST::Paragraph))

          self
        end
      end
    end
  end
end
