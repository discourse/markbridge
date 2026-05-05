#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Customizing the s9e/TextFormatter XML parser
#
# This demonstrates how to extend or override element mappings in the s9e/TextFormatter parser
# to handle custom XML elements or change the default behavior.

require "bundler/setup"
require "markbridge/textformatter"

# Example 1: Add a custom element mapping using a lambda
# =======================================================
#
# Suppose your forum uses a custom BBCode plugin that adds a <HIGHLIGHT> element
# to the s9e/TextFormatter XML output.

# Create a custom AST node (or reuse existing one)
class HighlightNode < Markbridge::AST::Element
  attr_reader :color

  def initialize(color: "yellow")
    super()
    @color = color
  end
end

# Create parser with custom lambda handler
parser =
  Markbridge::Parsers::TextFormatter::Parser.new do |registry|
    # Add lambda handler for custom HIGHLIGHT element
    registry.register(
      "HIGHLIGHT",
      lambda do |element:, parent:, processor:|
        attrs = {}
        element.attributes.each { |name, attr| attrs[name.downcase.to_sym] = attr.value }
        node = HighlightNode.new(color: attrs[:color] || "yellow")
        parent << node
        processor.process_children(element, node)
      end,
    )
  end

# Parse XML with custom element
xml = '<r>Normal text <HIGHLIGHT color="green">highlighted text</HIGHLIGHT> more text</r>'
ast = parser.parse(xml)

puts "Example 1: Custom element mapping with lambda"
puts "AST contains #{ast.children.length} elements"
highlight = ast.children.find { |c| c.is_a?(HighlightNode) }
puts "Highlight color: #{highlight&.color}"
puts

# Example 2: Override default element mapping with a handler class
# ==================================================================
#
# You can override default mappings by creating custom handler classes.

class CustomQuoteHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Quote
  end

  def process(element:, parent:, processor:)
    attrs = extract_attributes(element)
    # Add custom logic here - for example, default author to "Anonymous"
    quote =
      Markbridge::AST::Quote.new(
        author: attrs[:author] || "Anonymous",
        post: attrs[:post_id],
        topic: attrs[:topic_id],
        username: attrs[:username],
      )
    parent << quote
    processor.process_children(element, quote)
  end

  attr_reader :element_class
end

parser =
  Markbridge::Parsers::TextFormatter::Parser.new do |registry|
    # Override the default QUOTE handler with our custom handler
    registry.register("QUOTE", CustomQuoteHandler.new)
  end

xml = '<r><QUOTE author="John">Custom quote handling</QUOTE></r>'
ast = parser.parse(xml)

puts "Example 2: Override default mapping with handler class"
puts "Quote author: #{ast.children.first.author}"
puts

# Example 3: Building from defaults with multiple customizations using lambdas
# ==============================================================================

parser =
  Markbridge::Parsers::TextFormatter::Parser.new do |registry|
    # Override default spoiler with lambda
    registry.register(
      "SPOILER",
      lambda do |element:, parent:, processor:|
        attrs = {}
        element.attributes.each { |name, attr| attrs[name.downcase.to_sym] = attr.value }
        node = Markbridge::AST::Spoiler.new(title: attrs[:title] || "Click to reveal")
        parent << node
        processor.process_children(element, node)
      end,
    )

    # Map unknown custom element to text (leaf node, no children)
    registry.register(
      "CUSTOM",
      lambda do |element:, parent:, processor:|
        attrs = {}
        element.attributes.each { |name, attr| attrs[name.downcase.to_sym] = attr.value }
        parent << Markbridge::AST::Text.new("[CUSTOM: #{attrs[:value]}]")
      end,
    )

    # Add support for user mentions (leaf node)
    registry.register(
      "MENTION",
      lambda do |element:, parent:, processor:|
        attrs = {}
        element.attributes.each { |name, attr| attrs[name.downcase.to_sym] = attr.value }
        parent << Markbridge::AST::Text.new("@#{attrs[:username]}")
      end,
    )
  end

xml = '<r><SPOILER title="Secret">Hidden</SPOILER> <MENTION username="Alice"/></r>'
ast = parser.parse(xml)

puts "Example 3: Multiple customizations with lambdas"
puts "AST has #{ast.children.length} top-level elements"
puts

# Example 4: Using HandlerRegistry directly with handler objects
# ================================================================
#
# For more control, you can create a custom registry and pass it to the parser.

# Create a handler class for VIDEO elements
class VideoHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Url
  end

  def process(element:, parent:, processor:)
    attrs = extract_attributes(element)
    # Map VIDEO to a URL node (could create custom Video node instead)
    node = Markbridge::AST::Url.new(href: attrs[:url])
    parent << node
    processor.process_children(element, node)
  end

  attr_reader :element_class
end

registry = Markbridge::Parsers::TextFormatter::HandlerRegistry.new
registry.register_defaults # Load default handlers

# Add custom handler
registry.register("VIDEO", VideoHandler.new)

# Create parser with custom registry
parser = Markbridge::Parsers::TextFormatter::Parser.new(handlers: registry)

xml = '<r><VIDEO url="https://example.com/video.mp4">Watch video</VIDEO></r>'
ast = parser.parse(xml)

puts "Example 4: Custom handler registry with handler objects"
puts "Parsed video as URL: #{ast.children.first.href}"
puts

# Example 5: Preserving unknown elements vs. custom handling
# ===========================================================

# By default, unknown elements are preserved as text
default_parser = Markbridge::Parsers::TextFormatter::Parser.new

xml = '<r><UNKNOWN attr="value">content</UNKNOWN></r>'
ast = default_parser.parse(xml)

puts "Example 5: Unknown element preservation"
puts "Unknown elements tracked: #{default_parser.unknown_tags.inspect}"
puts "Content preserved as: #{ast.children.first.text.inspect}"
puts

puts "All examples completed successfully!"
