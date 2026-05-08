# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for self-closing leaf tags (br, hr, etc.). Creates
        # an instance of +element_class+, appends it to +parent+, and
        # returns nil so the parser does not try to recurse into
        # children.
        class SelfClosingHandler < BaseHandler
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
