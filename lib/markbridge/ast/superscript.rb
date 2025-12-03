# frozen_string_literal: true

module Markbridge
  module AST
    # Represents superscript text (e.g., for exponents).
    #
    # @example Superscript text
    #   sup = AST::Superscript.new
    #   sup << AST::Text.new("2")  # For x^2
    class Superscript < Element
    end
  end
end
