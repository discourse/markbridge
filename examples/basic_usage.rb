# frozen_string_literal: true

require_relative "../lib/markbridge/bbcode"

# Example 1: Basic formatting
result = Markbridge.bbcode_to_markdown("[b]Bold[/b] and [i]italic[/i] text")
puts result.markdown
# => "**Bold** and *italic* text"

# Example 2: Code blocks
result = Markbridge.bbcode_to_markdown("[code]def hello\n  puts 'world'\nend[/code]")
puts result.markdown
# => "```\ndef hello\n  puts 'world'\nend\n```"

# Example 3: Custom Tag via the renderer factory
class ShoutTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    interface.render_children(element, context: interface.with_parent(element)).upcase
  end
end

renderer = Markbridge.discourse_renderer(tags: { Markbridge::AST::Bold => ShoutTag.new })
result = Markbridge.bbcode_to_markdown("[b]hello[/b] world", renderer:)
puts result.markdown
# => "HELLO world"

# Example 4: Inspect parse-side data without rendering
parse = Markbridge.parse_bbcode("[b]hi[/b][unknownext]x[/unknownext]")
puts "AST root has #{parse.ast.children.size} children"
puts "unknown tags: #{parse.unknown_tags}"

# Example 5: Conversion result is more than just a string
result = Markbridge.bbcode_to_markdown("[b]hi[/b]")
puts "markdown: #{result.markdown.inspect}"
puts "format:   #{result.format}"
puts "errors:   #{result.errors.inspect}"
puts "string-coerce works: #{result}" # via to_s
