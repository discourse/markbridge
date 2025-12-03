# frozen_string_literal: true

module Markbridge
  module AST
    # Represents italic/emphasis text formatting.
    #
    # @example
    #   italic = AST::Italic.new
    #   italic << AST::Text.new("emphasized text")
    class Italic < Element
    end
  end
end
