# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Base class for TextFormatter XML element handlers
        #
        # Handlers process s9e/TextFormatter XML elements and convert them to AST nodes.
        # Each handler implements the process method to handle a specific element type.
        #
        # @abstract Subclass and override {#process} to implement a custom handler
        class BaseHandler
          # Process an XML element and convert it to AST node(s)
          #
          # @param element [Nokogiri::XML::Element] the XML element to process
          # @param parent [AST::Element] the parent AST node to add children to
          # @return [AST::Element, nil] the created element if children should be processed, nil otherwise
          def process(element:, parent:)
            raise NotImplementedError, "#{self.class} must implement #process"
          end

          # The AST element class this handler creates
          # Used for introspection and documentation
          #
          # @return [Class] the AST node class
          def element_class
            raise NotImplementedError, "#{self.class} must implement #element_class"
          end

          private

          # Extract attributes from XML element as a symbolized hash
          # @param element [Nokogiri::XML::Element]
          # @return [Hash<Symbol, String>] attributes hash with symbolized, lowercased keys
          def extract_attributes(element)
            attrs = {}
            element.attributes.each { |name, attr| attrs[name.downcase.to_sym] = attr.value }
            attrs
          end
        end
      end
    end
  end
end
