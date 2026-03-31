# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        class BaseHandler
          # Process a Nokogiri node and add it to the parent AST node
          # Subclasses should override this method
          # @param node [Nokogiri::XML::Element] the HTML element
          # @param parent [AST::Element] the parent AST node
          # @return [AST::Element, nil] the created element if children should be processed, nil otherwise
          def process(element:, parent:)
            # Default: do nothing, subclasses override
            nil
          end

          # The element class created by this handler
          # Subclasses must expose this via attr_reader :element_class
          # @return [Class]
          attr_reader :element_class
        end
      end
    end
  end
end
