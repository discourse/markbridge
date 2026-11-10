# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering colored text.
        #
        # Discourse core removes the style of a span. Only the
        # discourse-bbcode plugin can show colors, so the tag needs to
        # know whether the site has it. Until it knows, a color raises
        # {UndecidedFeatureError}.
        #
        # - +bbcode: nil+ (the default): a color raises.
        # - +bbcode: false+: the text only, as inline tokens that the
        #   serializer joins with the neighbors.
        # - +bbcode: true+: +[color=…]…[/color]+, with the value mapped
        #   through +colors:+ when there is a mapping. A value the plugin
        #   would not accept (+#rgb+, +#rrggbb+ or a name) raises
        #   ArgumentError; a mapping that returns nil drops the color on
        #   purpose.
        #
        # Inside a link the text is written without BBCode in every case,
        # Discourse doesn't render BBCode in the text of a link.
        class ColorTag < Tag
          # #rgb, #rrggbb or a color name. Anything else (and anything that
          # could end the BBCode tag early) is refused.
          VALUE = /\A(?:#\h{3}|#\h{6}|[a-z]+)\z/i
          private_constant :VALUE

          UNDECIDED =
            "a [color] tag needs a decision: pass features: { bbcode: false } to " \
              "Markbridge.discourse_renderer to write the text only, or " \
              "features: { bbcode: true } for the discourse-bbcode plugin"
          private_constant :UNDECIDED

          # @param bbcode [Boolean, nil] whether the site has discourse-bbcode
          # @param colors [Hash, #call, nil] a mapping from the source value
          #   to the value written. A Hash is read with +fetch+, so an
          #   unknown value raises KeyError.
          def initialize(bbcode: nil, colors: nil)
            @bbcode = bbcode
            @colors = colors
          end

          def render(element, interface)
            context = interface.with_parent(element)
            color = bbcode_color(element.color, interface)
            return interface.render_tokens(element, context:) if color.nil?

            content = interface.render_children(element, context:, following: "[/color]")
            # The style that the discourse-bbcode plugin lets through.
            return %(<span style="color:#{color}">#{content}</span>) if interface.html_mode?

            Paragraphs.wrap(content, "[color=#{color}]", "[/color]")
          end

          private

          # @return [String, nil] the color to write, nil for the text only
          def bbcode_color(value, interface)
            return if text_only?(value, interface)
            raise UndecidedFeatureError, UNDECIDED if @bbcode.nil?

            mapped = @colors ? apply(@colors, value) : value
            return mapped if mapped.nil? || VALUE.match?(mapped)

            raise ArgumentError,
                  "color #{value.inspect} maps to #{mapped.inspect}, discourse-bbcode accepts " \
                    "#rgb, #rrggbb or a name; pass colors: to map it, or to drop it with nil"
          end

          def apply(mapping, value)
            mapping.respond_to?(:call) ? mapping.call(value) : mapping.fetch(value)
          end

          # No value, the plugin decided against, or a link around it: the
          # text is all there can be, and no decision changes that.
          def text_only?(value, interface)
            value.to_s.match?(/\A[[:space:]]*\z/) || @bbcode == false ||
              interface.has_parent?(AST::Url) || interface.has_parent?(AST::Email)
          end
        end
      end
    end
  end
end
