# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for vBulletin 5 [IMG2] tags.
        #
        # Supports:
        # - [IMG2=JSON]{"src":"http://example.com/image.png",...}[/IMG2]
        # - [IMG2]http://example.com/image.png[/IMG2]
        class Img2Handler < BaseHandler
          def initialize(collector: RawContentCollector.new)
            @collector = collector
            @element_class = AST::Image
          end

          def on_open(token:, context:, registry:, tokens: nil)
            content = collect_content(token:, tokens:)
            return unless content

            src = extract_src(token, content.strip)
            return if src.nil? || src.empty?

            context.add_child(AST::Image.new(src:))
          end

          def on_close(token:, context:, registry:, tokens: nil)
            context.add_child(AST::Text.new(token.source))
          end

          attr_reader :element_class

          private

          def collect_content(token:, tokens:)
            return unless tokens
            return unless closing_tag_ahead?(token.tag, tokens)

            @collector.collect(token.tag, tokens).content
          end

          def closing_tag_ahead?(tag, tokens)
            tokens.peek_ahead(100).any? { |t| t.is_a?(TagEndToken) && t.tag == tag }
          end

          def extract_src(token, content)
            if token.attrs[:option]&.downcase == "json" && content.start_with?("{")
              $1 if content =~ /"src"\s*:\s*"([^"]+)"/
            else
              content
            end
          end
        end
      end
    end
  end
end
