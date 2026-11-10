# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Generic handler for elements that take a single attribute
        #
        # This handler extracts a specified attribute and passes it to the AST node constructor.
        # Use this for elements like COLOR, SIZE, ALIGN, SPOILER.
        #
        # @example
        #   # For <COLOR color="red">text</COLOR>
        #   handler = AttributeHandler.new(AST::Color, attribute: :color, param: :color)
        #   registry.register("COLOR", handler)
        #
        # @example With a fixed keyword for every node
        #   # <SPOILER title="..."> is a block in phpBB
        #   AttributeHandler.new(AST::Spoiler, attribute: :title, block: true)
        class AttributeHandler < BaseHandler
          # @param element_class [Class] the AST node class to instantiate
          # @param attribute [Symbol] the XML attribute name to extract
          # @param param [Symbol] the parameter name to pass to the AST node constructor
          # @param fixed [Hash{Symbol => Object}] more keywords, which every
          #   node gets next to the one from the attribute
          def initialize(element_class, attribute:, param: nil, **fixed)
            @element_class = element_class
            @attribute = attribute
            @param = param || attribute
            @fixed = fixed
          end

          def process(element:, parent:, processor: nil)
            attrs = extract_attributes(element)
            node = @element_class.new(**@fixed, @param => attrs[@attribute])
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
