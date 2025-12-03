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
            # Extract dimensions from attributes or option
            width = sanitize_dimension(token.attrs[:width])
            height = sanitize_dimension(token.attrs[:height])

            # Parse option for WIDTHxHEIGHT format (e.g., [img=100x200])
            if token.attrs[:option]&.match?(/^\d+x\d+$/i)
              dimensions = token.attrs[:option].split("x", 2)
              width = sanitize_dimension(dimensions[0])
              height = sanitize_dimension(dimensions[1])
            elsif token.attrs[:option]&.match?(/^\d+$/)
              # Just a number means width
              width = sanitize_dimension(token.attrs[:option])
            end

            # Content is the URL
            AST::Image.new(src: content, width:, height:)
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
