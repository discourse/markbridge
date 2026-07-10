# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Placeholder tag for rendering polls.
        #
        # This is a STUB implementation that outputs the original raw BBCode.
        # Applications using Markbridge should provide their own custom tag
        # to render polls as placeholders or convert them to another format.
        #
        # @example Custom renderer with placeholder
        #   class MyPollTag < Markbridge::Renderers::Discourse::Tags::PollTag
        #     def render(element, interface)
        #       id = register_poll(element)
        #       "<<POLL:#{id}>>"
        #     end
        #   end
        class PollTag < Tag
          def render(element, _interface)
            body = element.raw || build_poll_bbcode(element)
            # Bracket both sides with blank lines so the stub cooks as a
            # standalone block. Without the leading pair it degrades into list
            # soup when it follows inline text on the same line — which now
            # happens whenever a poll is hoisted out of an inline container,
            # and already happened for a poll written mid-line in the source.
            # (Same island form the html_mode contract wants.)
            "\n\n#{body}\n\n"
          end

          private

          def build_poll_bbcode(element)
            attrs = build_attributes(element)
            options = element.options.map { |opt| "* #{opt}" }.join("\n")

            "[poll#{attrs}]\n#{options}\n[/poll]"
          end

          NAMES_WITHOUT_ATTRIBUTE = Set[nil, "poll"].freeze
          private_constant :NAMES_WITHOUT_ATTRIBUTE

          def build_attributes(element)
            parts = []
            unless NAMES_WITHOUT_ATTRIBUTE.include?(element.name)
              parts << %( name="#{element.name}")
            end
            parts << %( type="#{element.type}") if element.type
            parts << %( results="#{element.results}") if element.results
            parts << %( public="true") if element.public
            parts << %( chartType="#{element.chart_type}") if element.chart_type

            parts.join
          end
        end
      end
    end
  end
end
