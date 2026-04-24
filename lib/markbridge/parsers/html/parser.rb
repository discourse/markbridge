# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      # Parses HTML into an AST using Nokogiri
      class Parser
        # Tags whose contents should be dropped entirely (not emitted as text).
        # These are raw-text/metadata elements whose children are either CSS,
        # JavaScript, or document metadata that shouldn't appear in output.
        IGNORED_TAGS = %w[style script head title noscript template].freeze

        attr_reader :unknown_tags

        # Create a new parser with optional custom handlers
        # @param handlers [HandlerRegistry, nil] custom handler registry, defaults to HandlerRegistry.default
        # @yield [HandlerRegistry] optional block to customize the default registry
        def initialize(handlers: nil, &block)
          @handlers =
            if block_given?
              HandlerRegistry.build_from_default(&block)
            else
              handlers || HandlerRegistry.default
            end
          @unknown_tags = Hash.new(0)
        end

        # Parse HTML string into an AST
        # @param input [String] HTML source
        # @return [AST::Document]
        def parse(input)
          @unknown_tags.clear

          # Parse HTML with Nokogiri. Using the generic HTML (HTML4) parser rather
          # than HTML5 because Nokogiri::HTML5 is not available on JRuby
          # (see sparklemotion/nokogiri#2227). Table support treats thead/tbody/tfoot
          # as transparent, so the parse-tree difference (HTML5 auto-inserts tbody,
          # HTML4 does not) has no effect on the AST.
          doc = Nokogiri::HTML.fragment(input)

          # Create root AST document
          document = AST::Document.new

          # Process all nodes
          doc.children.each { |node| process_node(node, document) }

          document
        end

        # Process child nodes of an element (used by handlers)
        # @param node [Nokogiri::XML::Element]
        # @param parent [AST::Element]
        def process_children(node, parent)
          node.children.each { |child| process_node(child, parent) }
        end

        private

        # Process a Nokogiri node and add it to the parent AST node
        # @param node [Nokogiri::XML::Node]
        # @param parent [AST::Element]
        def process_node(node, parent)
          case node
          when Nokogiri::XML::Text
            process_text_node(node, parent)
          when Nokogiri::XML::Element
            process_element_node(node, parent)
          end
        end

        # Process a text node
        # @param node [Nokogiri::XML::Text]
        # @param parent [AST::Element]
        def process_text_node(node, parent)
          text = node.text
          parent << AST::Text.new(text) unless text.empty?
        end

        # Process an element node
        # @param node [Nokogiri::XML::Element]
        # @param parent [AST::Element]
        def process_element_node(node, parent)
          tag_name = node.name.downcase
          return if IGNORED_TAGS.include?(tag_name)

          handler = @handlers[tag_name]

          if handler
            # Handler returns element if children should be processed, nil otherwise
            ast_element =
              if handler.respond_to?(:process)
                handler.process(element: node, parent:)
              else
                handler.call(element: node, parent:)
              end

            # Automatically process children if handler returned element
            process_children(node, ast_element) if ast_element
          else
            handle_unknown_tag(node, parent)
          end
        end

        # Handle unknown tag by tracking it and ignoring the wrapper
        # while still processing its children
        # @param node [Nokogiri::XML::Element]
        # @param parent [AST::Element]
        def handle_unknown_tag(node, parent)
          @unknown_tags[node.name.downcase] += 1
          process_children(node, parent)
        end
      end
    end
  end
end
