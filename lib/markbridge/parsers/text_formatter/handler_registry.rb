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
      class HandlerRegistry
        include Enumerable

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

        # Shared, deep-frozen default registry for the no-customization
        # fast path. Built once per process; {Parser} falls back to it
        # when no +handlers:+ are given, skipping the full registry
        # construction on every parse. Handlers are stateless after
        # construction, so sharing is safe across parsers and threads.
        #
        # @return [HandlerRegistry] the same frozen instance on every call
        def self.shared_default
          @shared_default ||= default.freeze
        end

        # Freeze the registry together with its internal Hash so that
        # registration on a shared instance fails loudly instead of
        # silently mutating state visible to every parser.
        def freeze
          @mappings.freeze
          @transparent_tags.freeze
          super
        end

        # Elements that are expected without a handler: <ESC> holds a
        # character that a backslash made literal, <E> an emoticon and
        # <EMOJI> an emoji, each with its text as content.
        DEFAULT_TRANSPARENT_TAGS = %w[ESC E EMOJI].freeze

        # @return [Set<String>] mutable set of element names that are not
        #   counted as unknown when they have no handler. Their content
        #   is processed like for any element without one.
        attr_reader :transparent_tags

        def initialize
          @mappings = {}
          @transparent_tags = Set.new(DEFAULT_TRANSPARENT_TAGS)
        end

        # Iterate over the registered (element_name, handler) pairs, in
        # the order of registration.
        # @yieldparam element_name [String]
        # @yieldparam handler [#process]
        # @return [Enumerator] when no block is given
        def each(&block)
          @mappings.each(&block)
        end

        # Register a handler for an element
        # @param element_name [String] XML element name (case-insensitive)
        # @param handler [#process] Handler object responding to `process(element:, parent:)`
        def register(element_name, handler)
          @mappings[element_name.upcase] = handler
        end

        # Look up the handler for an element name (case-insensitive).
        # @param element_name [String]
        # @return [#process, nil]
        def [](element_name)
          # Keys are always upcased and s9e/TextFormatter stores its tag
          # names in uppercase, so the fetch hits directly on the hot
          # path; the block normalizes only unusual lookups.
          @mappings.fetch(element_name) { @mappings[element_name.upcase] }
        end

        # Replace the handler bound to one or more element names by
        # yielding the previously-bound handler (which may be +nil+)
        # and registering whatever the block returns.
        #
        # @param element_names [String, Array<String>]
        # @yieldparam previous [#process, nil]
        # @return [self]
        def overlay(element_names)
          Array(element_names).each do |name|
            previous = self[name]
            register(name, yield(previous))
          end
          self
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
        # @param processor [Parser] the parser, exposed to handlers so
        #   they can call back into +process_children+ for nested content
        # @return [AST::Element, nil] the created element if children should be processed, nil otherwise
        def process_element(element, parent, processor)
          handler = self[element.name]
          handler&.process(element:, parent:, processor:)
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
          register("COLOR", Handlers::AttributeHandler.new(AST::Color, attribute: :color))
          register("SIZE", Handlers::AttributeHandler.new(AST::Size, attribute: :size))
          register(
            "ALIGN",
            Handlers::AttributeHandler.new(AST::Align, attribute: :align, param: :alignment),
          )
          # The alignment BBCodes of the s9e repository have no attribute,
          # the name says how to align. Flarum has [center] on.
          %w[CENTER LEFT RIGHT JUSTIFY].each do |name|
            register(name, Handlers::SimpleHandler.new(AST::Align, alignment: name.downcase))
          end
          # phpBB shows a [spoiler] as a block. ISPOILER is the inline
          # spoiler of Litedown.
          register(
            "SPOILER",
            Handlers::AttributeHandler.new(AST::Spoiler, attribute: :title, block: true),
          )
          register("ISPOILER", Handlers::SimpleHandler.new(AST::Spoiler))
          register("ATTACHMENT", Handlers::AttachmentHandler.new)
          register("ATTACH", Handlers::AttachmentHandler.new)

          register("LI", Handlers::SimpleHandler.new(AST::ListItem))

          # The [hr] BBCode of the s9e repository and a rule in Litedown
          register("HR", Handlers::SelfClosingHandler.new(AST::HorizontalRule))

          # Litedown, the Markdown plugin of s9e that Flarum uses. It has
          # its own elements for what BBCode has too: <STRONG> next to <B>.
          register("STRONG", Handlers::SimpleHandler.new(AST::Bold))
          register("EM", Handlers::SimpleHandler.new(AST::Italic))
          register("DEL", Handlers::SimpleHandler.new(AST::Strikethrough))
          register("SUP", Handlers::SimpleHandler.new(AST::Superscript))
          register("SUB", Handlers::SimpleHandler.new(AST::Subscript))
          # <C> is a code span, <CODE> a fenced block.
          register("C", Handlers::SimpleHandler.new(AST::Code))
          heading = Handlers::HeadingHandler.new
          %w[H1 H2 H3 H4 H5 H6].each { |name| register(name, heading) }

          # Paragraphs
          register("P", Handlers::SimpleHandler.new(AST::Paragraph))

          # Table elements
          register("TABLE", Handlers::SimpleHandler.new(AST::Table))
          register("TR", Handlers::SimpleHandler.new(AST::TableRow))
          register("TD", Handlers::TableCellHandler.new)
          register("TH", Handlers::TableCellHandler.new)
        end
      end
    end
  end
end
