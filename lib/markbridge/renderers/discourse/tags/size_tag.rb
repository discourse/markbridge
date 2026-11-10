# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering sized text.
        #
        # Discourse core removes the style of a span. Only the
        # discourse-bbcode plugin can show sizes, and it reads
        # +[size=…]+ as a percentage, as phpBB 3.x writes it. So the tag
        # needs to know two things: whether the site has the plugin, and
        # how the values of the source forum map to percent. Until it
        # knows the first, a size raises {UndecidedFeatureError}.
        #
        # - +bbcode: nil+ (the default): a size raises.
        # - +bbcode: false+: the text only, as inline tokens that the
        #   serializer joins with the neighbors.
        # - +bbcode: true+: +[size=…]…[/size]+, with the value mapped
        #   through +sizes:+. Without a mapping the value is taken as it
        #   is. A value that is not a whole number from 1 to 999 after the
        #   mapping raises ArgumentError; a mapping that returns nil drops
        #   the size on purpose.
        #
        # Inside a link the text is written without BBCode in every case,
        # Discourse doesn't render BBCode in the text of a link.
        class SizeTag < Tag
          # A whole number from 1 to 999, the range the plugin lets through.
          VALUE = /\A[1-9]\d{0,2}\z/
          private_constant :VALUE

          UNDECIDED =
            "a [size] tag needs a decision: pass features: { bbcode: false } to " \
              "Markbridge.discourse_renderer to write the text only, or " \
              "features: { bbcode: true } with sizes: for the discourse-bbcode plugin"
          private_constant :UNDECIDED

          # @param bbcode [Boolean, nil] whether the site has discourse-bbcode
          # @param sizes [Hash, #call, nil] the mapping from the source value
          #   to percent. A Hash is read with +fetch+, so an unknown value
          #   raises KeyError.
          def initialize(bbcode: nil, sizes: nil)
            @bbcode = bbcode
            @sizes = sizes
          end

          def render(element, interface)
            context = interface.with_parent(element)
            percent = bbcode_percent(element.size, interface)
            return interface.render_tokens(element, context:) if percent.nil?

            content = interface.render_children(element, context:, following: "[/size]")
            # The style that the discourse-bbcode plugin lets through.
            return %(<span style="font-size:#{percent}%">#{content}</span>) if interface.html_mode?

            Paragraphs.wrap(content, "[size=#{percent}]", "[/size]")
          end

          private

          # @return [String, nil] the percent to write, nil for the text only
          def bbcode_percent(value, interface)
            return if text_only?(value, interface)
            raise UndecidedFeatureError, UNDECIDED if @bbcode.nil?

            mapped = @sizes ? apply(@sizes, value) : value
            return if mapped.nil?

            text = mapped.to_s
            return text if VALUE.match?(text)

            raise ArgumentError,
                  "size #{value.inspect} maps to #{mapped.inspect}, discourse-bbcode accepts a " \
                    "whole number from 1 to 999 (percent); pass sizes: to map it, or to drop " \
                    "it with nil"
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
