# frozen_string_literal: true

module Markbridge
  # Result of a *_to_markdown / convert / render call.
  #
  # @!attribute [r] markdown
  #   @return [String] the rendered Discourse-flavored Markdown
  # @!attribute [r] ast
  #   @return [AST::Document] the AST that produced the markdown
  # @!attribute [r] format
  #   @return [Symbol] :bbcode, :html, :text_formatter_xml, or :mediawiki
  # @!attribute [r] unknown_tags
  #   @return [Hash{String => Integer}] tag-name → occurrence count
  # @!attribute [r] diagnostics
  #   @return [Hash{Symbol => Object}] format-specific diagnostics
  # @!attribute [r] errors
  #   @return [Array<StandardError>] render-time errors collected when
  #     +raise_on_error: false+ was passed; empty otherwise.
  Conversion =
    Data.define(:markdown, :ast, :format, :unknown_tags, :diagnostics, :errors) do
      # Allows +puts result+ and +"text: #{result}"+ to work seamlessly.
      def to_s
        markdown
      end
    end
end
