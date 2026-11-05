# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Renders {AST::Event} as the +[event]+ BBCode of the discourse-events
        # plugin: the raw BBCode of the source when the parser kept it,
        # otherwise the BBCode built from the attributes.
        #
        # With +bbcode: false+, for a site without the plugin, the event is
        # a paragraph with the name and the dates, so the reader still sees
        # it.
        #
        # @example A placeholder for the importer
        #   class MyEventTag < Markbridge::Renderers::Discourse::Tags::EventTag
        #     def render(element, interface)
        #       id = register_event(element)
        #       "<<EVENT:#{id}>>"
        #     end
        #   end
        class EventTag < Tag
          # @param bbcode [Boolean] write the BBCode of the plugin
          def initialize(bbcode: true)
            @bbcode = bbcode
          end

          def render(element, interface)
            return without_plugin(element, interface) unless @bbcode

            body = element.raw || build_event_bbcode(element)
            "\n\n#{body}\n\n"
          end

          private

          def without_plugin(element, interface)
            dates = [element.starts_at, element.ends_at].map(&:to_s).reject(&:empty?).join(" to ")
            text = [element.name.to_s, dates].reject(&:empty?).join(", ")
            return "" if text.empty?

            interface.render_node(AST::Paragraph.new << AST::Text.new(text))
          end

          def build_event_bbcode(element)
            attrs = build_attributes(element)
            "[event#{attrs}]\n[/event]"
          end

          def build_attributes(element)
            parts = []
            parts << %( name="#{element.name}")
            parts << %( start="#{element.starts_at}")
            parts << %( end="#{element.ends_at}") if element.ends_at
            parts << %( status="#{element.status}") if element.status
            parts << %( timezone="#{element.timezone}") if element.timezone

            parts.join
          end
        end
      end
    end
  end
end
