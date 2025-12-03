# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a paragraph element.
    #
    # @example
    #   paragraph = AST::Paragraph.new
    #   paragraph << AST::Text.new("This is a paragraph.")
    class Paragraph < Element
    end
  end
end
