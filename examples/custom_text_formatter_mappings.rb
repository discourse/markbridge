#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Customizing the s9e/TextFormatter XML parser
#
# Demonstrates how to extend or override element mappings in the
# s9e/TextFormatter parser by registering Handler classes. Every
# handler must respond to `#process(element:, parent:, processor:)`
# and return either an AST element (parser recurses into children)
# or nil (leaf — no further processing).

require "bundler/setup"
require "markbridge/textformatter"

# ----------------------------------------------------------------
# Example 1: Add a custom element mapping
# ----------------------------------------------------------------
#
# Suppose your forum uses a custom BBCode plugin that adds a
# <HIGHLIGHT> element to the s9e/TextFormatter XML output. Provide
# a Handler that constructs your AST node and recurses into the
# element's children.

class HighlightNode < Markbridge::AST::Element
  attr_reader :color

  def initialize(color: "yellow")
    super()
    @color = color
  end
end

class HighlightHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize
    @element_class = HighlightNode
  end

  def process(element:, parent:, processor:)
    attrs = extract_attributes(element)
    node = HighlightNode.new(color: attrs[:color] || "yellow")
    parent << node
    processor.process_children(element, node)
    nil # we recursed manually; don't double-process
  end

  attr_reader :element_class
end

parser =
  Markbridge::Parsers::TextFormatter::Parser.new do |registry|
    registry.register("HIGHLIGHT", HighlightHandler.new)
  end

xml = '<r>Normal text <HIGHLIGHT color="green">highlighted text</HIGHLIGHT> more text</r>'
ast = parser.parse(xml)

puts "Example 1: Custom element mapping"
puts "AST contains #{ast.children.length} elements"
highlight = ast.children.find { |c| c.is_a?(HighlightNode) }
puts "Highlight color: #{highlight&.color}"
puts

# ----------------------------------------------------------------
# Example 2: Override a default mapping with a custom handler class
# ----------------------------------------------------------------
#
# Just register your handler under the same name; it overwrites the
# default. Returning the constructed element lets the parser recurse
# into children automatically.

class CustomQuoteHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Quote
  end

  def process(element:, parent:, processor: nil)
    attrs = extract_attributes(element)
    quote =
      Markbridge::AST::Quote.new(
        author: attrs[:author] || "Anonymous",
        post_id: attrs[:post_id]&.to_i,
        topic_id: attrs[:topic_id]&.to_i,
        username: attrs[:username],
      )
    parent << quote
    quote # returning the node lets the parser process children into it
  end

  attr_reader :element_class
end

parser =
  Markbridge::Parsers::TextFormatter::Parser.new do |registry|
    registry.register("QUOTE", CustomQuoteHandler.new)
  end

xml = '<r><QUOTE author="John">Custom quote handling</QUOTE></r>'
ast = parser.parse(xml)

puts "Example 2: Override default mapping"
puts "Quote author: #{ast.children.first.author}"
puts

# ----------------------------------------------------------------
# Example 3: Multiple customizations on top of the defaults
# ----------------------------------------------------------------
#
# A leaf-node handler returns nil; the parser does not recurse.
# A wrapping handler returns the AST node it just appended.

class CustomSpoilerHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Spoiler
  end

  def process(element:, parent:, processor: nil)
    attrs = extract_attributes(element)
    node = Markbridge::AST::Spoiler.new(title: attrs[:title] || "Click to reveal")
    parent << node
    node
  end

  attr_reader :element_class
end

class CustomTextHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Text
  end

  def process(element:, parent:, processor: nil)
    attrs = extract_attributes(element)
    parent << Markbridge::AST::Text.new("[CUSTOM: #{attrs[:value]}]")
    nil # leaf
  end

  attr_reader :element_class
end

class MentionHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Text
  end

  def process(element:, parent:, processor: nil)
    attrs = extract_attributes(element)
    parent << Markbridge::AST::Text.new("@#{attrs[:username]}")
    nil # leaf
  end

  attr_reader :element_class
end

parser =
  Markbridge::Parsers::TextFormatter::Parser.new do |registry|
    registry.register("SPOILER", CustomSpoilerHandler.new)
    registry.register("CUSTOM", CustomTextHandler.new)
    registry.register("MENTION", MentionHandler.new)
  end

xml = '<r><SPOILER title="Secret">Hidden</SPOILER> <MENTION username="Alice"/></r>'
ast = parser.parse(xml)

puts "Example 3: Multiple customizations"
puts "AST has #{ast.children.length} top-level elements"
puts

# ----------------------------------------------------------------
# Example 4: Building a HandlerRegistry directly
# ----------------------------------------------------------------
#
# For more control, build the registry yourself and pass it via
# `handlers:` instead of using the block form.

class VideoHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Url
  end

  def process(element:, parent:, processor: nil)
    attrs = extract_attributes(element)
    node = Markbridge::AST::Url.new(href: attrs[:url])
    parent << node
    node # parser will process children into the returned node
  end

  attr_reader :element_class
end

registry = Markbridge::Parsers::TextFormatter::HandlerRegistry.new
registry.register_defaults # Load default handlers
registry.register("VIDEO", VideoHandler.new)

parser = Markbridge::Parsers::TextFormatter::Parser.new(handlers: registry)

xml = '<r><VIDEO url="https://example.com/video.mp4">Watch video</VIDEO></r>'
ast = parser.parse(xml)

puts "Example 4: Custom handler registry"
puts "Parsed video as URL: #{ast.children.first.href}"
puts

# ----------------------------------------------------------------
# Example 5: Unknown elements
# ----------------------------------------------------------------
#
# By default, unknown elements are preserved as text and tracked
# in `parser.unknown_tags`.

default_parser = Markbridge::Parsers::TextFormatter::Parser.new

xml = '<r><UNKNOWN attr="value">content</UNKNOWN></r>'
ast = default_parser.parse(xml)

puts "Example 5: Unknown element preservation"
puts "Unknown elements tracked: #{default_parser.unknown_tags.inspect}"
puts "Content preserved as: #{ast.children.first.text.inspect}"
puts

puts "All examples completed successfully!"
