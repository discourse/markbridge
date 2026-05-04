# frozen_string_literal: true

# AST Nodes
require_relative "../ast"

# Parser components
require_relative "media_wiki/inline_tag_registry"
require_relative "media_wiki/inline_parser"
require_relative "media_wiki/parser"

module Markbridge
  module Parsers
    module MediaWiki
    end
  end
end
