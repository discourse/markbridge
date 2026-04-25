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

          OPTION_DIMENSIONS_PATTERN = /\A(?<width>\d+)(?:x(?<height>\d+))?\z/i
          private_constant :OPTION_DIMENSIONS_PATTERN

          def extract_dimensions(token)
            option_match = OPTION_DIMENSIONS_PATTERN.match(token.attrs[:option])

            [
              sanitize_dimension(option_match&.[](:width) || token.attrs[:width]),
              sanitize_dimension(option_match&.[](:height) || token.attrs[:height]),
            ]
          end

          def sanitize_dimension(value)
            dim = value.to_i
            dim if dim.positive?
          end
        end
      end
    end
  end
end
