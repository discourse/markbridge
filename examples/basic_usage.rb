# frozen_string_literal: true

require_relative "../lib/markbridge/bbcode"

# Example 1: Basic formatting
bbcode = "[b]Bold[/b] and [i]italic[/i] text"
markdown = Markbridge.bbcode_to_markdown(bbcode)
puts markdown
# => "**Bold** and *italic* text"

# Example 2: Code blocks
bbcode = "[code]def hello\n  puts 'world'\nend[/code]"
markdown = Markbridge.bbcode_to_markdown(bbcode)
puts markdown
# => "```\ndef hello\n  puts 'world'\nend\n```"

# Example 3: Custom handlers and tags
# Create custom handler registry
handlers = Markbridge::Parsers::BBCode::HandlerRegistry.new

# Add a simple custom element
class CustomElement < Markbridge::AST::Element
end

# Register handler for custom tag
custom_handler = Markbridge::Parsers::BBCode::Handlers::SimpleHandler.new(CustomElement)
handlers.register("custom", custom_handler)
handlers.register_element_handler(CustomElement, custom_handler)

# # Create custom tag library for rendering
# tag_library = Markbridge::Renderers::Discourse::TagLibrary.new
# custom_tag =
#   Markbridge::Renderers::Discourse::Tag.new do |element, renderer|
#     content = renderer.render_children(element)
#     "<<#{content}>>"
#   end
# tag_library.register(CustomElement, custom_tag)
#
# markdown =
#   Markbridge.bbcode_to_markdown(
#     "[custom]test[/custom]",
#     handlers:,
#     tag_library:
#   )
# puts markdown
# # => "<<test>>"

# Example 4: Parse to AST and inspect
ast = Markbridge.parse_bbcode("[b]Hello[/b]")
puts ast.inspect
# You'll see Bold instead of BoldElement

# Example 5: Nested lists (ordered and unordered)
bbcode = <<~BBCODE
  [list]
  [*]Item 1
  [*]Item 2
  [list=1]
  [*]Subitem 2.1
  [*]Subitem 2.2
  [/list]
  [*]Item 3
  [/list]
BBCODE

markdown = Markbridge.bbcode_to_markdown(bbcode)
puts markdown
# =>
# - Item 1
# - Item 2
#   1. Subitem 2.1
#   2. Subitem 2.2
# - Item 3
