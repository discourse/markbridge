# frozen_string_literal: true

module Markbridge
  # Result of a *_to_markdown / convert / render call.
  #
  # Wraps a {Parse} (the input-side fields: +ast+, +format+,
  # +unknown_tags+, +diagnostics+) and adds the render-side outputs:
  # +markdown+ and +errors+. The wrapped {Parse} is reachable via
  # {#parse}, and each of its fields is also exposed as a delegated
  # reader so the common usage stays ergonomic
  # (+conversion.ast+, +conversion.unknown_tags+, …) without forcing
  # callers to chain through +#parse+.
  #
  # @!attribute [r] parse
  #   @return [Parse] the parsed input — also reachable as
  #     +Markbridge.render(conversion.parse, …)+ for re-render.
  # @!attribute [r] markdown
  #   @return [String] the rendered Discourse-flavored Markdown
  # @!attribute [r] errors
  #   @return [Array<StandardError>] render-time errors collected when
  #     +raise_on_error: false+ was passed; empty otherwise.
  # @!method ast
  #   @return [AST::Document] delegated to {Parse#ast}
  # @!method format
  #   @return [Symbol] delegated to {Parse#format}
  # @!method unknown_tags
  #   @return [Hash{String => Integer}] delegated to {Parse#unknown_tags}
  # @!method diagnostics
  #   @return [Hash{Symbol => Object}] delegated to {Parse#diagnostics}
  Conversion =
    Data.define(:parse, :markdown, :errors) do
      def ast = parse.ast
      def format = parse.format
      def unknown_tags = parse.unknown_tags
      def diagnostics = parse.diagnostics

      # Allows +puts result+ and +"text: #{result}"+ to work seamlessly.
      def to_s = markdown
    end
end
