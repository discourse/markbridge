# frozen_string_literal: true

# base / dependency order first
require_relative "ast/node"
require_relative "ast/element"
require_relative "ast/document"

require_relative "ast/align"
require_relative "ast/attachment"
require_relative "ast/bold"
require_relative "ast/code"
require_relative "ast/color"
require_relative "ast/details"
require_relative "ast/email"
require_relative "ast/heading"
require_relative "ast/horizontal_rule"
require_relative "ast/image"
require_relative "ast/italic"
require_relative "ast/line_break"
require_relative "ast/list"
require_relative "ast/list_item"
require_relative "ast/table"
require_relative "ast/paragraph"
require_relative "ast/quote"
require_relative "ast/size"
require_relative "ast/spoiler"
require_relative "ast/strikethrough"
require_relative "ast/subscript"
require_relative "ast/superscript"
require_relative "ast/text"
require_relative "ast/markdown_text"
require_relative "ast/underline"
require_relative "ast/url"

# Discourse-specific nodes
require_relative "ast/event"
require_relative "ast/mention"
require_relative "ast/poll"
require_relative "ast/upload"

module Markbridge
  module AST
  end
end
