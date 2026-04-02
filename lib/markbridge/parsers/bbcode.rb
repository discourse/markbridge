# frozen_string_literal: true

# AST Nodes
require_relative "../ast"

# Errors
require_relative "bbcode/errors/max_depth_exceeded_error"

# Tokens
require_relative "bbcode/tokens/token"
require_relative "bbcode/tokens/text_token"
require_relative "bbcode/tokens/tag_start_token"
require_relative "bbcode/tokens/tag_end_token"

# Closing Strategies
require_relative "bbcode/closing_strategies/tag_reconciler"
require_relative "bbcode/closing_strategies/base"
require_relative "bbcode/closing_strategies/strict"
require_relative "bbcode/closing_strategies/reordering"

# Base Handlers
require_relative "bbcode/handlers/base_handler"
require_relative "bbcode/handlers/raw_handler"

# Handlers
require_relative "bbcode/handlers/align_handler"
require_relative "bbcode/handlers/attachment_handler"
require_relative "bbcode/handlers/color_handler"
require_relative "bbcode/handlers/email_handler"
require_relative "bbcode/handlers/image_handler"
require_relative "bbcode/handlers/img2_handler"
require_relative "bbcode/handlers/list_handler"
require_relative "bbcode/handlers/list_item_handler"
require_relative "bbcode/handlers/quote_handler"
require_relative "bbcode/handlers/self_closing_handler"
require_relative "bbcode/handlers/simple_handler"
require_relative "bbcode/handlers/size_handler"
require_relative "bbcode/handlers/spoiler_handler"
require_relative "bbcode/handlers/url_handler"

# Parser components
require_relative "bbcode/handler_registry"
require_relative "bbcode/parser_state"
require_relative "bbcode/peekable_enumerator"
require_relative "bbcode/raw_content_result"
require_relative "bbcode/raw_content_collector"
require_relative "bbcode/scanner"

# Parser
require_relative "bbcode/parser"

module Markbridge
  module Parsers
    module BBCode
    end
  end
end
