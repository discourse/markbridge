# frozen_string_literal: true

module Markbridge
  module AST
    # Represents text that was added to a document, the +<ins>+ of HTML.
    # A browser shows it underlined, but it is not underline formatting.
    #
    # @example Inserted text
    #   insertion = AST::Insertion.new
    #   insertion << AST::Text.new("new wording")
    class Insertion < Element
    end
  end
end
