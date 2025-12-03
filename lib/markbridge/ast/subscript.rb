# frozen_string_literal: true

module Markbridge
  module AST
    # Represents subscript text (e.g., for chemical formulas).
    #
    # @example Subscript text
    #   sub = AST::Subscript.new
    #   sub << AST::Text.new("2")  # For H2O
    class Subscript < Element
    end
  end
end
