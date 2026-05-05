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
  # @!attribute [r] emissions
  #   @return [Hash{Symbol => Array}] side-channel records emitted by
  #     custom Tags via +interface.emit(key, payload)+.
  # @!attribute [r] errors
  #   @return [Array<StandardError>] render-time errors collected when
  #     +raise_on_error: false+ was passed; empty otherwise.
  Conversion =
    Data.define(:markdown, :ast, :format, :unknown_tags, :diagnostics, :emissions, :errors) do
      # Allows +puts result+ and +"text: #{result}"+ to work seamlessly.
      def to_s
        markdown
      end

      # Convenience accessor — returns +[]+ for keys that were never
      # emitted, so callers don't have to nil-check.
      #
      # @param key [Symbol]
      # @return [Array]
      def emitted(key)
        emissions.fetch(key, [])
      end
    end
end
