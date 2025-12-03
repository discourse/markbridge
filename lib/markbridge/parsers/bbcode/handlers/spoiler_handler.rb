# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for SPOILER tags
        # Supports:
        # - [spoiler]text[/spoiler]
        # - [spoiler=title]text[/spoiler]
        # - [hide]text[/hide] (alias for spoiler)
        class SpoilerHandler < BaseHandler
          def initialize
            @element_class = AST::Spoiler
          end

          def on_open(token:, context:, registry:, tokens: nil)
            title = token.attrs[:title] || token.attrs[:option]
            element = AST::Spoiler.new(title:)
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
