# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      # Parses s9e/TextFormatter XML format into an AST
      #
      # The s9e/TextFormatter library (https://github.com/s9e/TextFormatter) stores BBCode as XML:
      # - Plain text: <t>text content</t>
      # - Rich text: <r><B>bold</B> <URL url="...">link</URL></r>
      # - Markup preservation: <s> and <e> elements (ignored during parsing)
      #
      # This format is used by phpBB 3.2+ and other forum software.
      #
      # Requires Nokogiri gem to be installed. Add to your Gemfile:
      #   gem "nokogiri"
      class Parser
        attr_reader :unknown_tags

        # Create a new parser with optional custom handler registry
        # @param handlers [HandlerRegistry, nil] custom handler registry, defaults to HandlerRegistry.default
        # @yield [HandlerRegistry] optional block to customize the default registry
        # @example Using default mappings
        #   parser = Parser.new
        # @example Using custom registry
        #   parser = Parser.new(handlers: my_registry)
        # @example Customizing default mappings
        #   parser = Parser.new do |registry|
        #     registry.register("CUSTOM", MyCustomHandler.new)
        #   end
        def initialize(handlers: nil, &block)
          @handlers =
            if block_given?
              HandlerRegistry.build_from_default(&block)
            else
              handlers || HandlerRegistry.default
            end
          @unknown_tags = Hash.new(0)
        end

        # Parse s9e/TextFormatter XML into an AST
        # @param input [String] XML string in s9e/TextFormatter format
        # @return [AST::Document]
        def parse(input)
          @unknown_tags.clear

          xml_doc = Nokogiri.XML(input)
          root = xml_doc.root

          unless root
            # Invalid or non-XML - treat as plain text
            document = AST::Document.new
            document << AST::Text.new(input) unless input.empty?
            return document
          end

          document = AST::Document.new
          process_node(root, document)
          document
        rescue Nokogiri::XML::SyntaxError => e
          # Invalid XML - treat as plain text
          document = AST::Document.new
          document << AST::Text.new(input)
          document
        end

        # Process children of an XML element (public for handler access)
        # @param element [Nokogiri::XML::Element]
        # @param ast_parent [AST::Element]
        def process_children(element, ast_parent)
          element.children.each { |child| process_node(child, ast_parent) }
        end

        private

        # Process an XML node and add corresponding AST nodes to parent
        # @param xml_node [Nokogiri::XML::Element, Nokogiri::XML::Text]
        # @param ast_parent [AST::Element]
        def process_node(xml_node, ast_parent)
          if xml_node.element?
            process_element(xml_node, ast_parent)
          elsif xml_node.text?
            process_text(xml_node, ast_parent)
          end
        end

        # Process an XML element
        # @param element [Nokogiri::XML::Element]
        # @param ast_parent [AST::Element]
        def process_element(element, ast_parent)
          tag_name = element.name

          # Skip markup preservation elements and their content (used for unparsing)
          return if %w[s e].include?(tag_name)

          # Handle root nodes
          return process_children(element, ast_parent) if %w[t r].include?(tag_name)

          # Handle line breaks
          if tag_name == "br"
            ast_parent << AST::LineBreak.new
            return
          end

          # Process element with registered handler
          # Handler returns element if children should be processed, nil otherwise
          result_element = @handlers.process_element(element, ast_parent)

          if result_element
            # Handler succeeded and returned element - process children into it
            process_children(element, result_element)
          elsif !@handlers.has_handler?(tag_name)
            # No handler found - track as unknown and process children directly
            @unknown_tags[tag_name] += 1
            process_children(element, ast_parent)
          end
          # else: handler returned nil intentionally (no children to process)
        end

        # Process text node
        # @param text_node [Nokogiri::XML::Text]
        # @param ast_parent [AST::Element]
        def process_text(text_node, ast_parent)
          text = text_node.content
          return if text.strip.empty?

          ast_parent << AST::Text.new(text)
        end
      end
    end
  end
end
