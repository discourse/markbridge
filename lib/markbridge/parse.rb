# frozen_string_literal: true

module Markbridge
  # Result of a parse-only call (Markbridge.parse_bbcode and friends).
  #
  # @!attribute [r] ast
  #   @return [AST::Document]
  # @!attribute [r] format
  #   @return [Symbol] :bbcode, :html, :text_formatter_xml, or :mediawiki
  # @!attribute [r] unknown_tags
  #   @return [Hash{String => Integer}] tag-name → occurrence count.
  #     Empty for parsers that do not yet track unknown tags.
  # @!attribute [r] diagnostics
  #   @return [Hash{Symbol => Object}] format-specific diagnostics.
  #     BBCode supplies :auto_closed_tags_count, :depth_exceeded_count,
  #     :unclosed_raw_tags. Other parsers supply an empty hash for now.
  Parse = Data.define(:ast, :format, :unknown_tags, :diagnostics)
end
