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

          def process(element:, parent:, processor: nil)
            attrs = extract_attributes(element)
            node =
              AST::Attachment.new(
                id: attrs[:id],
                index: attrs[:index],
                filename: attrs[:filename],
                alt: attrs[:alt],
              )
            parent << node

            # The content is only fallback text (the filename), so there are
            # no children to process.
            nil
          end

          attr_reader :element_class
        end
      end
    end
  end
end
