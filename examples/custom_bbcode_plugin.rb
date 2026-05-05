# frozen_string_literal: true

# Example: Creating a custom BBCode plugin module
#
# This demonstrates how to organize custom BBCode handlers into reusable modules
# that can be easily loaded into a parser.

require "markbridge/bbcode"

# Example 1: Simple Quote Tag Plugin
module QuotePlugin
  # Custom AST element for quotes
  class Quote < Markbridge::AST::Element
    attr_reader :author

    def initialize(author: nil)
      super()
      @author = author
    end
  end

  # Handler for [quote] tags
  class QuoteHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
    def initialize
      @element_class = Quote
    end

    def on_open(token:, context:, registry:, tokens: nil)
      author = token.attrs[:option]
      element = Quote.new(author:)
      context.push(element)
    end

    attr_reader :element_class
  end

  # Register this plugin with a registry
  def self.register(registry)
    registry.register("quote", QuoteHandler.new)
  end
end

# Example 2: Color Tag Plugin (non-standard BBCode)
module ColorPlugin
  class ColorText < Markbridge::AST::Element
    attr_reader :color

    def initialize(color: nil)
      super()
      @color = color
    end
  end

  class ColorHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
    def initialize
      @element_class = ColorText
    end

    def on_open(token:, context:, registry:, tokens: nil)
      color = token.attrs[:option]
      element = ColorText.new(color:)
      context.push(element)
    end

    attr_reader :element_class
  end

  def self.register(registry)
    registry.register("color", ColorHandler.new)
  end
end

# Example 3: Spoiler Tag Plugin (auto-closeable)
module SpoilerPlugin
  class Spoiler < Markbridge::AST::Element
  end

  class SpoilerHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
    def initialize
      @element_class = Spoiler
    end

    def on_open(token:, context:, registry:, tokens: nil)
      element = Spoiler.new
      context.push(element)
    end

    def auto_closeable?
      true
    end

    attr_reader :element_class
  end

  def self.register(registry)
    registry.register("spoiler", SpoilerHandler.new)
  end
end

# Usage Example 1: Using Parser.new with block
parser =
  Markbridge::Parsers::BBCode::Parser.new do |registry|
    QuotePlugin.register(registry)
    ColorPlugin.register(registry)
    SpoilerPlugin.register(registry)
  end

# Usage Example 2: Using HandlerRegistry.build_from_default
registry =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |reg|
    QuotePlugin.register(reg)
    ColorPlugin.register(reg)
  end
parser = Markbridge::Parsers::BBCode::Parser.new(handlers: registry)

# Usage Example 3: Selective plugin loading based on configuration
def create_parser(features: [])
  Markbridge::Parsers::BBCode::Parser.new do |registry|
    QuotePlugin.register(registry) if features.include?(:quotes)
    ColorPlugin.register(registry) if features.include?(:colors)
    SpoilerPlugin.register(registry) if features.include?(:spoilers)
  end
end

# Create parser with only quote and spoiler support
parser = create_parser(features: %i[quotes spoilers])

# Parse with custom tags
ast = parser.parse("[quote=John]Hello [spoiler]secret[/spoiler][/quote]")

puts "Plugin system loaded successfully!"
puts "AST contains #{ast.children.length} top-level elements"
