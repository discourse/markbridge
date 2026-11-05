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
        # @example A placeholder for the importer
        #   class MyPollTag < Markbridge::Renderers::Discourse::Tags::PollTag
        #     def render(element, interface)
        #       id = register_poll(element)
        #       "<<POLL:#{id}>>"
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

          private

          def without_plugin(element, interface)
            return "" if element.options.empty?

            list = AST::List.new(ordered: false)
            element.options.each do |option|
              list << (AST::ListItem.new << AST::Text.new(option.to_s))
            end
            interface.render_node(list, context: interface.with_parent(element))
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
