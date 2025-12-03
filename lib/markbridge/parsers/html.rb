# frozen_string_literal: true

# Dependencies
require_relative "../gem_loader"
Markbridge::GemLoader.require_gem(:nokogiri, feature: "HTML parsing")

# AST Nodes
require_relative "../ast"

# Handlers
require_relative "html/handlers/base_handler"
require_relative "html/handlers/simple_handler"
require_relative "html/handlers/raw_handler"
require_relative "html/handlers/url_handler"
require_relative "html/handlers/image_handler"
require_relative "html/handlers/list_handler"
require_relative "html/handlers/list_item_handler"
require_relative "html/handlers/quote_handler"
require_relative "html/handlers/paragraph_handler"

# Parser components
require_relative "html/handler_registry"
require_relative "html/parser"

module Markbridge
  module Parsers
    module HTML
    end
  end
end
