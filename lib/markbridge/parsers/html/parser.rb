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
              handlers || HandlerRegistry.shared_default
            end
          @unknown_tags = Hash.new(0)
        end

        # Parse HTML into an AST.
        #
        # Accepts either a String of HTML source or a pre-parsed
        # Nokogiri node (typically a +DocumentFragment+ from
        # +Nokogiri::HTML.fragment+ or a full +Document+ from
        # +Nokogiri::HTML.parse+). Passing a pre-parsed tree lets a
        # caller run their own Nokogiri-driven pre-processing without
        # forcing Markbridge to re-parse the same bytes.
        #
        # A +Nokogiri::HTML::Document+ is unwrapped to its +<body>+
        # children so the +<html>+ / +<body>+ / +<head>+ wrappers
        # don't pollute {#unknown_tags}; fragments and bare elements
        # iterate their own children directly.
        #
        # @param input [String, Nokogiri::XML::Node] HTML source or
        #   pre-parsed Nokogiri tree
        # @return [AST::Document]
        def parse(input)
          @unknown_tags.clear

          # Parse HTML with Nokogiri. Using the generic HTML (HTML4) parser rather
          # than HTML5 because Nokogiri::HTML5 is not available on JRuby
          # (see sparklemotion/nokogiri#2227). Table support treats thead/tbody/tfoot
          # as transparent, so the parse-tree difference (HTML5 auto-inserts tbody,
          # HTML4 does not) has no effect on the AST.
          doc =
            if input.is_a?(Nokogiri::XML::Node)
              input
            else
              Nokogiri::HTML.fragment(input.to_s)
            end

          children = doc.is_a?(Nokogiri::HTML::Document) ? body_children(doc) : doc.children

          # Create root AST document
          document = AST::Document.new

          # Whitespace preservation is tracked during descent instead of
          # walking node.ancestors per text node; seed the counter from
          # the parse root's real ancestry so pre-parsed subtrees inside
          # a <pre> keep their semantics.
          @preserve_depth = initial_preserve_depth(doc)

          # Process all nodes
          children.each { |node| process_node(node, document) }
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

        # Anything WHITESPACE_RUN would actually change: a non-space
        # whitespace character, or two-plus consecutive spaces. Prose with
        # only single spaces passes through without the gsub copy.
        COLLAPSIBLE_WHITESPACE = /[\t\r\n\f]| {2}/
        private_constant :COLLAPSIBLE_WHITESPACE

        # Anything String#rstrip would remove from the end (ASCII
        # whitespace or NUL), or the empty string.
        TRAILING_STRIPPABLE = /[\0\t\n\v\f\r ]\z|\A\z/
        private_constant :TRAILING_STRIPPABLE

        # Process a text node
        # @param node [Nokogiri::XML::Text]
        # @param parent [AST::Element]
        def process_text_node(node, parent)
          text = node.text

          if @preserve_depth.positive?
            parent << AST::Text.new(text)
            return
          end

          text = text.gsub(WHITESPACE_RUN, " ") if text.match?(COLLAPSIBLE_WHITESPACE)
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

          # Drop whitespace that sits between content and the start of a
          # block-level tag, matching browser behavior where such whitespace
          # collapses against the block boundary. Applies whether or not a
          # handler is registered, so unknown tags like <div> or <section>
          # still collapse the whitespace before them.
          trim_trailing_whitespace(parent) if @handlers.block_level_tags.include?(tag_name)

          preserving = @handlers.whitespace_preserving_tags.include?(tag_name)
          @preserve_depth += 1 if preserving

          dispatch_element(node, tag_name, parent, preserving)

          @preserve_depth -= 1 if preserving
        end

        # Dispatch an element to its handler (or the unknown-tag path) and
        # process its children.
        # @param node [Nokogiri::XML::Element]
        # @param tag_name [String]
        # @param parent [AST::Element]
        # @param preserving [Boolean] whether this tag preserves whitespace
        def dispatch_element(node, tag_name, parent, preserving)
          handler = @handlers[tag_name]
          return handle_unknown_tag(node, parent) unless handler

          # Handler returns element if children should be processed, nil otherwise
          ast_element = handler.process(element: node, parent:)

          return unless ast_element

          process_children(node, ast_element)
          trim_trailing_whitespace(ast_element) unless preserving
        end

        # Handle unknown tag by tracking it and ignoring the wrapper
        # while still processing its children
        # @param node [Nokogiri::XML::Element]
        # @param parent [AST::Element]
        def handle_unknown_tag(node, parent)
          @unknown_tags[node.name] += 1
          process_children(node, parent)
        end

        # Number of whitespace-preserving elements enclosing the parse
        # root, the root itself included. Computed once per parse; from
        # there the counter is maintained during descent. Documents and
        # fragments count themselves harmlessly — their #name
        # ("document", "#document-fragment") never matches a tag set.
        # @param root [Nokogiri::XML::Node]
        # @return [Integer]
        def initial_preserve_depth(root)
          [root, *root.ancestors].count do |node|
            @handlers.whitespace_preserving_tags.include?(node.name)
          end
        end

        # Direct children of the +<body>+ element of a full HTML document,
        # falling back to the document's own children if no +<body>+ exists
        # (malformed input).
        # @param doc [Nokogiri::HTML::Document]
        # @return [Nokogiri::XML::NodeSet]
        def body_children(doc)
          (doc.at_css("body") || doc).children
        end

        # Strip trailing whitespace from the last Text child of `element`.
        # Removes the child entirely if it becomes empty. No-op if the last
        # child is not a Text node.
        # @param element [AST::Element]
        def trim_trailing_whitespace(element)
          last = element.children.last
          return unless last.instance_of?(AST::Text)

          # Fast exit when there is nothing to strip: no trailing byte
          # rstrip would remove (ASCII whitespace or NUL), and not the
          # empty string (which the pop below drops entirely).
          return unless last.text.match?(TRAILING_STRIPPABLE)

          trimmed = last.text.rstrip
          element.children.pop
          element << AST::Text.new(trimmed) unless trimmed.empty?
        end
      end
    end
  end
end
