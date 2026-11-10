# frozen_string_literal: true

module Markbridge
  module AST
    # Represents highlighted text, the +<mark>+ of HTML.
    #
    # @example Highlighted text
    #   highlight = AST::Highlight.new
    #   highlight << AST::Text.new("important")
    class Highlight < Element
    end
  end
end
