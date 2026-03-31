# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Placeholder tag for rendering mentions.
        #
        # This is a STUB implementation that outputs a placeholder.
        # Applications using Markbridge should provide their own custom tag
        # or use the raw mention format.
        #
        # @example Custom renderer that preserves original format
        #   class MyMentionTag < Markbridge::Renderers::Discourse::Tags::MentionTag
        #     def render(element, interface)
        #       "@#{element.name}"
        #     end
        #   end
        #
        # @example Custom renderer that links to user
        #   class MyMentionTag < Markbridge::Renderers::Discourse::Tags::MentionTag
        #     def render(element, interface)
        #       "[@#{element.name}](/u/#{element.name})"
        #     end
        #   end
        class MentionTag < Tag
          def render(element, _interface)
            "@#{element.name}"
          end
        end
      end
    end
  end
end
