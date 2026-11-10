# frozen_string_literal: true

module Markbridge
  module AST
    # Represents text that was removed from a document, the +<del>+ of
    # HTML. A browser shows it struck through, but it is not
    # strikethrough formatting.
    #
    # @example Deleted text
    #   deletion = AST::Deletion.new
    #   deletion << AST::Text.new("old wording")
    class Deletion < Element
    end
  end
end
