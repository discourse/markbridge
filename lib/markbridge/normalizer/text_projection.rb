# frozen_string_literal: true

module Markbridge
  class Normalizer
    # Best-effort plain-text projection of a subtree, used by the
    # +:textify+ strategy. Concatenates text content; renders a {AST::Mention}
    # as its literal +@name+, and opaque leaf nodes as their alt/raw text
    # when they carry one, otherwise the empty string.
    module TextProjection
      class << self
        # @param node [AST::Node]
        # @return [String]
        def call(node)
          case node
          when AST::Text, AST::MarkdownText
            node.text
          when AST::Mention
            "@#{node.name}"
          when AST::Element
            node.children.map { |child| call(child) }.join
          else
            leaf_text(node)
          end
        end

        # @param node [AST::Node] an opaque leaf (Upload, Attachment, …)
        # @return [String]
        def leaf_text(node)
          return node.alt if node.respond_to?(:alt) && node.alt
          return node.raw if node.respond_to?(:raw) && node.raw

          ""
        end
      end
    end
  end
end
