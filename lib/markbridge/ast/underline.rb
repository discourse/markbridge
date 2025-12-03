# frozen_string_literal: true

module Markbridge
  module AST
    # Represents underlined text formatting.
    #
    # @example
    #   underline = AST::Underline.new
    #   underline << AST::Text.new("underlined text")
    class Underline < Element
    end
  end
end
