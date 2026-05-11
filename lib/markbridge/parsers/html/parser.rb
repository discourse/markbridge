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

        # Tags whose default rendering preserves source whitespace (per the
        # CSS `white-space: pre*` family). Text nodes inside these are passed
        # through verbatim; outside them, `\s+` runs collapse to a single space
        # to match HTML's normal whitespace handling.
        WHITESPACE_PRESERVING_TAGS = %w[pre code textarea tt].freeze

        WHITESPACE_RUN = /[ \t\r\n\f]+/

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
          trim_trailing_whitespace(document)

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
          if preserves_whitespace?(node)
            parent << AST::Text.new(node.text)
            return
          end

          text = node.text.gsub(WHITESPACE_RUN, " ")
          # Drop leading whitespace at the start of an element's content,
          # matching the browser rule that whitespace at the beginning of a
          # block (or before any inline content) is collapsed away.
          text = text.lstrip if parent.children.empty?
          return if text.empty?

          parent << AST::Text.new(text)
        end

        # Process an element node
        # @param node [Nokogiri::XML::Element]
        # @param parent [AST::Element]
        def process_element_node(node, parent)
          tag_name = node.name
          return if IGNORED_TAGS.include?(tag_name)

          handler = @handlers[tag_name]

          if handler
            # Drop whitespace that sits between content and the start of a
            # block-level AST node, matching browser behavior where such
            # whitespace collapses against the block boundary. Block-ness is
            # marked on the produced AST class via `include AST::Block`.
            trim_trailing_whitespace(parent) if produces_block?(handler)

            # Handler returns element if children should be processed, nil otherwise
            ast_element =
              if handler.respond_to?(:process)
                handler.process(element: node, parent:)
              else
                handler.call(element: node, parent:)
              end

            # Automatically process children if handler returned element
            if ast_element
              process_children(node, ast_element)
              unless WHITESPACE_PRESERVING_TAGS.include?(tag_name)
                trim_trailing_whitespace(ast_element)
              end
            end
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

        # Whether `node` is inside a tag that preserves source whitespace.
        # @param node [Nokogiri::XML::Node]
        # @return [Boolean]
        def preserves_whitespace?(node)
          node.ancestors.any? { |ancestor| WHITESPACE_PRESERVING_TAGS.include?(ancestor.name) }
        end

        # Whether the handler produces a block-level AST node. Returns false
        # for Proc handlers, which don't advertise their element class.
        # @param handler [BaseHandler, Proc]
        # @return [Boolean]
        def produces_block?(handler)
          return false unless handler.respond_to?(:element_class)

          element_class = handler.element_class
          !element_class.nil? && element_class < AST::Block
        end

        # Strip trailing whitespace from the last Text child of `element`.
        # Removes the child entirely if it becomes empty. No-op if the last
        # child is not a Text node.
        # @param element [AST::Element]
        def trim_trailing_whitespace(element)
          last = element.children.last
          return unless last.instance_of?(AST::Text)

          trimmed = last.text.rstrip
          element.children.pop
          element << AST::Text.new(trimmed) unless trimmed.empty?
        end
      end
    end
  end
end
