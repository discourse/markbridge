# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handles <h1> through <h6> by creating a Heading element with the
        # matching level and processing children into it.
        class HeadingHandler < BaseHandler
          # @param element [Nokogiri::XML::Element] the heading element
          # @param parent [AST::Element] the parent AST node
          # @return [AST::Heading] the created heading, so children get processed into it
          def process(element:, parent:)
            level = element.name.delete_prefix("h").to_i.clamp(1, 6)
            heading = AST::Heading.new(level:)
            parent << heading

            heading
          end

          # @return [Class] AST::Heading
          def element_class
            AST::Heading
          end
        end
      end
    end
  end
end
