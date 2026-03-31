# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for IMG tags
        # Supports:
        # - [img]url[/img]
        # - [img=100x100]url[/img]
        # - [img width=100]url[/img]
        # - [img width=100 height=50]url[/img]
        class ImageHandler < RawHandler
          def initialize
            super(AST::Image)
          end

          private

          def create_element(token:, content:)
            width, height = extract_dimensions(token)
            AST::Image.new(src: content, width:, height:)
          end

          def extract_dimensions(token)
            width = sanitize_dimension(token.attrs[:width])
            height = sanitize_dimension(token.attrs[:height])

            option = token.attrs[:option]
            if option&.match?(/^\d+x\d+$/i)
              parts = option.split("x", 2)
              width = sanitize_dimension(parts[0])
              height = sanitize_dimension(parts[1])
            elsif option&.match?(/^\d+$/)
              width = sanitize_dimension(option)
            end

            [width, height]
          end

          # Convert dimension to positive integer or nil
          # Handles string input from BBCode attributes
          def sanitize_dimension(value)
            return nil if value.nil?

            dim = value.to_i
            dim.positive? ? dim : nil
          end
        end
      end
    end
  end
end
