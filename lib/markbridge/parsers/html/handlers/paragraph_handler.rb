# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for <p> tags
        # Creates AST::Paragraph nodes to preserve paragraph boundaries
        class ParagraphHandler < SimpleHandler
          def initialize
            super(AST::Paragraph)
          end
        end
      end
    end
  end
end
