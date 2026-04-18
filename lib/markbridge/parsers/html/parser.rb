# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      # Parses HTML into an AST using Nokogiri
      class Parser
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

          # Parse HTML with Nokogiri
          doc = Nokogiri::HTML5.fragment(input)

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
          parent << AST::Text.new(node.text)
        end

        # Process an element node
        # @param node [Nokogiri::XML::Element]
        # @param parent [AST::Element]
        def process_element_node(node, parent)
          tag_name = node.name
          handler = @handlers[tag_name]

          if handler
            ast_element = handler.process(element: node, parent:)
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
          @unknown_tags[node.name] += 1
          process_children(node, parent)
        end
      end
    end
  end
end
