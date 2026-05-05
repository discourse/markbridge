# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for raw/preformatted tags that preserve content as-is
        # Uses RawContentCollector strategy to consume tokens until closing tag
        # without parsing nested BBCode
        class RawHandler < BaseHandler
          def initialize(element_class, collector: RawContentCollector.new)
            @element_class = element_class
            @collector = collector
          end

          def on_open(token:, context:, registry:, tokens:)
            result = @collector.collect(token.tag, tokens)
            context.mark_unclosed_raw!(token.tag) if result.unclosed?

            element = create_element(token:, content: result.content)
            context.add_child(element)
          end

          # The collector consumes the closing tag, so this fires only when a
          # `[/raw]` token leaks past the collector — treat it as literal text.
          def on_close(token:, context:, registry:, tokens: nil)
            context.add_child(AST::Text.new(token.source))
          end

          attr_reader :element_class

          private

          def create_element(token:, content:)
            element =
              if accepts_language?
                @element_class.new(language: token.attrs[:lang] || token.attrs[:option])
              else
                @element_class.new
              end
            element << AST::Text.new(content) unless content.empty?
            element
          end

          # Cache the introspection — the AST class doesn't change for
          # the lifetime of this handler.
          def accepts_language?
            return @accepts_language if defined?(@accepts_language)

            @accepts_language =
              @element_class.instance_method(:initialize).parameters.any? do |_kind, name|
                name == :language
              end
          end
        end
      end
    end
  end
end
