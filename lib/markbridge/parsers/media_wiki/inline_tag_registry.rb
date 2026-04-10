# frozen_string_literal: true

module Markbridge
  module Parsers
    module MediaWiki
      # Registry of inline HTML-like tag handlers for the MediaWiki parser.
      #
      # Supports three tag types:
      # - :raw — content is preserved verbatim (e.g., <code>, <nowiki>)
      # - :formatting — content is parsed for inline wiki markup (e.g., <s>, <u>)
      # - :self_closing — no content, produces a leaf AST node (e.g., <br>)
      #
      # @example Default usage
      #   registry = InlineTagRegistry.default
      #   entry = registry["s"]
      #   entry.type           # => :formatting
      #   entry.element_class  # => AST::Strikethrough
      #
      # @example Custom registration
      #   registry = InlineTagRegistry.build_from_default do |r|
      #     r.register("mark", :formatting, AST::Bold)
      #   end
      class InlineTagRegistry
        Entry = Data.define(:type, :element_class)

        def initialize
          @entries = {}
        end

        # Register a handler for an inline HTML-like tag.
        #
        # @param tag_name [String] the tag name (case-insensitive)
        # @param type [:raw, :formatting, :self_closing] how the tag content is handled
        # @param element_class [Class] the AST node class to create
        # @return [self]
        def register(tag_name, type, element_class)
          validate_type!(type)
          @entries[tag_name.to_s.downcase] = Entry.new(type:, element_class:)
          self
        end

        # Look up a tag entry by name.
        #
        # @param tag_name [String]
        # @return [Entry, nil]
        def [](tag_name)
          @entries[tag_name.to_s.downcase]
        end

        # Check if a tag name is registered.
        #
        # @param tag_name [String]
        # @return [Boolean]
        def known?(tag_name)
          @entries.key?(tag_name.to_s.downcase)
        end

        # Create the default registry with standard MediaWiki inline tags.
        #
        # @return [InlineTagRegistry]
        def self.default
          registry = new

          # Raw tags — content preserved verbatim, not parsed for wiki markup
          registry.register("nowiki", :raw, nil)
          registry.register("code", :raw, AST::Code)
          registry.register("pre", :raw, AST::Code)

          # Formatting tags — content parsed for inline wiki markup
          registry.register("s", :formatting, AST::Strikethrough)
          registry.register("del", :formatting, AST::Strikethrough)
          registry.register("u", :formatting, AST::Underline)
          registry.register("ins", :formatting, AST::Underline)
          registry.register("sup", :formatting, AST::Superscript)
          registry.register("sub", :formatting, AST::Subscript)

          # Self-closing tags — produce a leaf node, no content
          registry.register("br", :self_closing, AST::LineBreak)

          registry
        end

        # Build a registry from the default with optional customization.
        #
        # @yield [InlineTagRegistry] the registry to customize
        # @return [InlineTagRegistry]
        def self.build_from_default
          registry = default
          yield(registry) if block_given?
          registry
        end

        private

        VALID_TYPES = %i[raw formatting self_closing].freeze

        def validate_type!(type)
          return if VALID_TYPES.include?(type)

          raise ArgumentError, "type must be one of #{VALID_TYPES.inspect}, got #{type.inspect}"
        end
      end
    end
  end
end
