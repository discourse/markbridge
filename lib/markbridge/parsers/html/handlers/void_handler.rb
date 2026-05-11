# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for void HTML elements (no children, no attributes consumed).
        # Mirrors SimpleHandler but returns nil from #process so the parser
        # skips child traversal — appropriate for tags like <br> and <hr>.
        class VoidHandler < BaseHandler
          def initialize(element_class)
            @element_class = element_class
          end

          def process(element:, parent:)
            parent << @element_class.new
            nil
          end

          attr_reader :element_class
        end
      end
    end
  end
end
