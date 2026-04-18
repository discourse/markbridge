# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
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
