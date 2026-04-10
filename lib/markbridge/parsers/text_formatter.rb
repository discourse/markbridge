# frozen_string_literal: true

# Dependencies
require_relative "../gem_loader"
Markbridge::GemLoader.require_gem(:nokogiri, feature: "s9e/TextFormatter XML parsing")

# AST Nodes
require_relative "../ast"

# Handler classes
require_relative "text_formatter/handlers/base_handler"
require_relative "text_formatter/handlers/simple_handler"
require_relative "text_formatter/handlers/attribute_handler"
require_relative "text_formatter/handlers/attachment_handler"
require_relative "text_formatter/handlers/code_handler"
require_relative "text_formatter/handlers/email_handler"
require_relative "text_formatter/handlers/image_handler"
require_relative "text_formatter/handlers/list_handler"
require_relative "text_formatter/handlers/quote_handler"
require_relative "text_formatter/handlers/url_handler"
require_relative "text_formatter/handlers/table_cell_handler"

# Parser components
require_relative "text_formatter/handler_registry"
require_relative "text_formatter/parser"

module Markbridge
  module Parsers
    module TextFormatter
    end
  end
end
