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
      # - Ignored text: <i> (lowercase) holds text s9e did not use, like the
      #   newline after [list] or a stray [/b]. It is skipped too; <I> is italic.
      # - Line breaks: <br/> followed by a newline in the next text node. The
      #   newline is only source formatting, like any whitespace at the start
      #   of a line, because phpBB renders the XML as HTML. Inside <CODE> the
      #   text is kept as it is.
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
              handlers || HandlerRegistry.shared_default
            end
          @unknown_tags = Hash.new(0)
          # Whether an AST class is one of the BLOCK_NODES, computed once
          # per class, so an inline element doesn't check all of them.
          @block_classes =
            Hash.new do |block_class_cache, klass|
              block_class_cache[klass] = BLOCK_NODES.any? { klass <= _1 }
            end
        end

        # Parse s9e/TextFormatter XML into an AST.
        #
        # Accepts either a String of XML or a pre-parsed Nokogiri node.
        # A +Nokogiri::XML::Document+ is unwrapped via +#root+; any
        # other node is treated as the root itself.
        #
        # @param input [String, Nokogiri::XML::Node] XML source or
        #   pre-parsed Nokogiri tree
        # @return [AST::Document]
        def parse(input)
          @unknown_tags.clear
          @line_start = true

          if input.is_a?(Nokogiri::XML::Node)
            root = input.is_a?(Nokogiri::XML::Document) ? input.root : input
            document = AST::Document.new
            process_node(root, document) if root
            flush_line_break
            return document
          end

          input = input.to_s
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
          flush_line_break
          document
        rescue Nokogiri::XML::SyntaxError
          AST::Document.new << AST::Text.new(input)
        end

        # <s>/<e> hold the original BBCode markup for unparsing, <i> holds
        # text that s9e ignored; <t>/<r> are the plain-text/rich-text roots.
        # Frozen constants — the membership checks run once per element
        # node. The check is case-sensitive: <I> is italic.
        MARKUP_PRESERVATION_TAGS = %w[s e i].freeze
        ROOT_TAGS = %w[t r].freeze

        # AST nodes that phpBB shows as blocks. A new line starts before and
        # after them, so whitespace at the start of their content and of the
        # text after them is not visible.
        BLOCK_NODES = [
          AST::Align,
          AST::Details,
          AST::Heading,
          AST::HorizontalRule,
          AST::List,
          AST::ListItem,
          AST::Paragraph,
          AST::Quote,
          AST::Table,
          AST::TableCell,
          AST::TableRow,
        ].freeze
        private_constant :MARKUP_PRESERVATION_TAGS, :ROOT_TAGS, :BLOCK_NODES

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
          return if MARKUP_PRESERVATION_TAGS.include?(tag_name)

          # Handle root nodes
          return process_children(element, ast_parent) if ROOT_TAGS.include?(tag_name)

          return process_line_break(ast_parent) if tag_name == "br"

          # Process element with registered handler
          # Handler returns element if children should be processed, nil otherwise
          flush_line_break
          result_element = @handlers.process_element(element, ast_parent, self)

          if result_element
            # Handler succeeded and returned element - process children into it
            process_handled_children(element, result_element)
          elsif @handlers.has_handler?(tag_name)
            # The handler returned nil intentionally: a leaf like an image
            # or an attachment, whose content is only fallback text. It is
            # visible, so the text after it is no longer at the line start,
            # unless the leaf is a block like a horizontal rule.
            @line_start = block?(ast_parent.children.last)
          else
            # No handler found - track as unknown and process children directly
            @unknown_tags[tag_name] += 1
            process_children(element, ast_parent)
          end
        end

        # Two line breaks in a row are an empty line in phpBB. In Markdown
        # that is a paragraph break, so a line break waits in
        # +@pending_break+ until something visible follows it. When the
        # next line break comes first, the two become a blank line. A
        # third one comes after the blank line and is not visible.
        #
        # @param ast_parent [AST::Element]
        def process_line_break(ast_parent)
          if @pending_break.equal?(ast_parent)
            @pending_break = nil
            ast_parent << AST::Text.new("\n\n")
          else
            flush_line_break
            @pending_break = ast_parent
          end
          @line_start = true
        end

        # Adds the line break that waits, if there is one, before anything
        # visible is added after it.
        def flush_line_break
          @pending_break&.<<(AST::LineBreak.new)
          @pending_break = nil
        end

        # Whether the forum shows +node+ as a block: one of the BLOCK_NODES,
        # or a spoiler or code that says so. An inline spoiler and a code
        # span are part of their line.
        #
        # @param node [AST::Node, nil]
        def block?(node)
          return node.block if node.is_a?(AST::Spoiler) || node.is_a?(AST::Code)

          @block_classes[node.class]
        end

        # @param element [Nokogiri::XML::Element]
        # @param ast_element [AST::Element]
        def process_handled_children(element, ast_element)
          if block?(ast_element)
            @line_start = true
            process_children(element, ast_element)
            @line_start = true
          else
            process_children(element, ast_element)
          end
        end

        # Process text node
        #
        # Outside of code, whitespace at the start of a line is not visible
        # in phpBB, but in Markdown a newline after a line break would end
        # the paragraph and four spaces would start a code block, so it is
        # removed. Whitespace-only text between two inline elements (the
        # space in "<B>a</B> <I>b</I>") is kept; with a newline in it, it
        # is only formatting between blocks.
        #
        # @param text_node [Nokogiri::XML::Text]
        # @param ast_parent [AST::Element]
        def process_text(text_node, ast_parent)
          text = text_node.content

          if ast_parent.is_a?(AST::Code)
            # Code is visible, so what follows a code span is not at the
            # start of its line anymore. After a code block the line
            # starts again, see process_handled_children.
            if text.match?(/\S/)
              ast_parent << AST::Text.new(text)
              @line_start = false
            end
          elsif @line_start
            text = text.lstrip
            return if text.empty?

            @line_start = false
            flush_line_break
            ast_parent << AST::Text.new(text)
          elsif text.match?(/\S/) || !text.include?("\n")
            ast_parent << AST::Text.new(text)
          end
        end
      end
    end
  end
end
