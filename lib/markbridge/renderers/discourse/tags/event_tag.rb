# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Placeholder tag for rendering events.
        #
        # This is a STUB implementation that outputs the original raw BBCode.
        # Applications using Markbridge should provide their own custom tag
        # to render events as placeholders or convert them to another format.
        #
        # @example Custom renderer with placeholder
        #   class MyEventTag < Markbridge::Renderers::Discourse::Tags::EventTag
        #     def render(element, interface)
        #       id = register_event(element)
        #       "<<EVENT:#{id}>>"
        #     end
        #   end
        class EventTag < Tag
          def render(element, _interface)
            body = element.raw || build_event_bbcode(element)
            # Bracket both sides with blank lines so the stub cooks as a
            # standalone block. Without the leading pair it degrades into list
            # soup when it follows inline text on the same line — which now
            # happens whenever an event is hoisted out of an inline container,
            # and already happened for an event written mid-line in the source.
            # (Same island form the html_mode contract wants.)
            "\n\n#{body}\n\n"
          end

          private

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
