# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a Discourse +[details=…]…[/details]+ collapsible section.
    #
    # Carries a +title+ string (used as the +summary+ text when the
    # block renders) and any child nodes.
    #
    # @example
    #   block = AST::Details.new(title: "Show more")
    #   block << AST::Text.new("Hidden body")
    class Details < Element
      # @return [String, nil] the summary / collapsed-state label
      attr_reader :title

      # @param title [String, nil] optional summary text
      def initialize(title: nil)
        super()
        @title = title
      end
    end
  end
end
