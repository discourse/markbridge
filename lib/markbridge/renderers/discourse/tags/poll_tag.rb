# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Renders {AST::Poll} as the +[poll]+ BBCode of the poll plugin: the
        # raw BBCode of the source when the parser kept it, otherwise the
        # BBCode built from the attributes and the options.
        #
        # With +bbcode: false+, for a site without the plugin, the options
        # are written as a bullet list. The raw BBCode is of no use there.
        #
        # A poll is a block, so a placeholder for it keeps the blank lines
        # around it (see "Placeholders" in the migration guide).
        #
        # @example A placeholder for the importer
        #   class MyPollTag < Markbridge::Renderers::Discourse::Tags::PollTag
        #     def render(element, interface)
        #       id = register_poll(element)
        #       "\n\n<<POLL:#{id}>>\n\n"
        #     end
        #   end
        class PollTag < Tag
          # @param bbcode [Boolean] write the BBCode of the plugin
          def initialize(bbcode: true)
            @bbcode = bbcode
          end

          def render(element, interface)
            return without_plugin(element, interface) unless @bbcode

            body = element.raw || build_poll_bbcode(element)
            "\n\n#{body}\n\n"
          end

          # The plain form is a bullet list, so a bullet list next to the
          # poll would continue it (see Tag#leading_list). The poll stands
          # for the list, the marker is chosen for it.
          def leading_list(element, _interface)
            element unless @bbcode
          end

          def trailing_list(element, _interface)
            element unless @bbcode
          end

          private

          # The options as the items of a bullet list, one line each; a
          # poll without options renders to nothing, like an empty list.
          # The poll writes the lines itself, with the marker the renderer
          # picks for it against the list in front.
          def without_plugin(element, interface)
            return "" if element.options.empty?
            if interface.html_mode?
              items = element.options.map { |option| "<li>#{HtmlEscaper.escape(option)}</li>" }
              return "<ul>#{items.join}</ul>"
            end

            marker = interface.choose_list_marker(element, ordered: false)
            context = interface.with_parent(element)
            lines =
              element.options.map do |option|
                "#{marker}#{interface.render_node(AST::Text.new(option), context:)}"
              end
            "\n\n#{lines.join("\n")}\n\n"
          end

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
