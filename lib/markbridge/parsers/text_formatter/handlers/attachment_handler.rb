# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for ATTACHMENT and ATTACH elements in s9e/TextFormatter XML
        class AttachmentHandler < BaseHandler
          def initialize
            @element_class = AST::Attachment
          end

          def process(element:, parent:)
            attrs = extract_attributes(element)
            node =
              AST::Attachment.new(
                id: attrs[:id],
                index: attrs[:index],
                filename: attrs[:filename],
                alt: attrs[:alt],
              )
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
