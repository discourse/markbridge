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
            # Trailing blank line so consecutive polls don't merge and
            # following content is treated as a separate block.
            body = element.raw || build_poll_bbcode(element)
            "#{body}\n\n"
          end

          private

          def build_poll_bbcode(element)
            attrs = build_attributes(element)
            options = element.options.map { |opt| "* #{opt}" }.join("\n")

            "[poll#{attrs}]\n#{options}\n[/poll]"
          end

          def build_attributes(element)
            parts = []
            parts << %( name="#{element.name}") if element.name && element.name != "poll"
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
