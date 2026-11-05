# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering colored text.
        #
        # Discourse core removes the style of a span. Only the
        # discourse-bbcode plugin can show colors, so by default the tag
        # renders only the text, as inline tokens that the serializer joins
        # with the neighbors. With +bbcode: true+ it writes
        # +[color=…]…[/color]+ for the plugin (see
        # +Markbridge.discourse_renderer(features: { bbcode: true })+).
        class ColorTag < Tag
          # #rgb, #rrggbb or a color name. Anything else (and anything that
          # could end the BBCode tag early) renders only the text.
          VALUE = /\A(?:#\h{3}|#\h{6}|[a-z]+)\z/i
          private_constant :VALUE

          # @param bbcode [Boolean] write the color as BBCode
          def initialize(bbcode: false)
            @bbcode = bbcode
          end

          def render(element, interface)
            context = interface.with_parent(element)
            color = element.color
            return interface.render_tokens(element, context:) unless styled?(color, interface)

            content = interface.render_children(element, context:)
            # The style that the discourse-bbcode plugin lets through.
            return %(<span style="color:#{color}">#{content}</span>) if interface.html_mode?

            Paragraphs.wrap(content, "[color=#{color}]", "[/color]")
          end

          private

          # Discourse doesn't render BBCode inside the text of a link.
          def styled?(color, interface)
            @bbcode && VALUE.match?(color) && !interface.has_parent?(AST::Url) &&
              !interface.has_parent?(AST::Email)
          end
        end
      end
    end
  end
end
