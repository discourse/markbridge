# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering sized text.
        #
        # Discourse core removes the style of a span. Only the
        # discourse-bbcode plugin can show sizes, so by default the tag
        # renders only the text, as inline tokens that the serializer joins
        # with the neighbors. With +bbcode: true+ it writes
        # +[size=…]…[/size]+ for the plugin (see
        # +Markbridge.discourse_renderer(styling_bbcode: true)+). The
        # plugin reads the value as a percentage, like phpBB 3.x does.
        class SizeTag < Tag
          # A whole number from 1 to 999, the range the plugin lets through.
          VALUE = /\A[1-9]\d{0,2}\z/
          private_constant :VALUE

          # @param bbcode [Boolean] write the size as BBCode
          def initialize(bbcode: false)
            @bbcode = bbcode
          end

          def render(element, interface)
            context = interface.with_parent(element)
            size = element.size.to_s
            return interface.render_tokens(element, context:) unless styled?(size, interface)

            content = interface.render_children(element, context:)
            # The style that the discourse-bbcode plugin lets through.
            return %(<span style="font-size:#{size}%">#{content}</span>) if interface.html_mode?

            Paragraphs.wrap(content, "[size=#{size}]", "[/size]")
          end

          private

          # Discourse doesn't render BBCode inside the text of a link.
          def styled?(size, interface)
            @bbcode && VALUE.match?(size) && !interface.has_parent?(AST::Url) &&
              !interface.has_parent?(AST::Email)
          end
        end
      end
    end
  end
end
