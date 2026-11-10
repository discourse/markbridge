# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for simple XML elements that don't require attributes
        #
        # This handler creates an AST node of the specified class and processes
        # all child elements. Use this for simple formatting tags like B, I, U, S.
        #
        # @example
        #   handler = SimpleHandler.new(AST::Bold)
        #   registry.register("B", handler)
        #
        # @example With keywords for every node
        #   # [center] has no attribute, the name says how to align
        #   SimpleHandler.new(AST::Align, alignment: "center")
        class SimpleHandler < BaseHandler
          # @param element_class [Class] the AST node class to instantiate
          # @param options [Hash{Symbol => Object}] keywords every node gets
          def initialize(element_class, **options)
            @element_class = element_class
            @options = options
          end

          # Process the element by creating an AST node and processing children
          # @param element [Nokogiri::XML::Element]
          # @param parent [AST::Element]
          def process(element:, parent:, processor: nil)
            node = @element_class.new(**@options)
            parent << node

            # Return node to signal: process children into this node
            node
          end

          attr_reader :element_class
        end
      end
    end
  end
end
