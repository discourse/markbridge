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
            # Trailing blank line so consecutive events don't merge and
            # following content is treated as a separate block.
            body = element.raw || build_event_bbcode(element)
            "#{body}\n\n"
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
