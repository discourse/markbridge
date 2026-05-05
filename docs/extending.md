# Extending Markbridge

This guide shows you how to add custom BBCode tags and renderers to Markbridge. Whether you need to support forum-specific tags or create custom output formats, this guide covers all the extension points.

## Table of Contents

- [Overview](#overview)
- [Adding a New BBCode Tag](#adding-a-new-bbcode-tag)
- [Creating Custom Handlers](#creating-custom-handlers)
- [Creating Custom Renderers](#creating-custom-renderers)
- [Plugin Pattern](#plugin-pattern)
- [Advanced Examples](#advanced-examples)
- [Best Practices](#best-practices)

## Overview

Markbridge provides three main extension points:

1. **Parser Extension** - Add support for new BBCode tags
2. **Renderer Extension** - Customize Markdown output
3. **Both** - Add complete end-to-end support for custom tags

**Extension Flow:**
```
1. Create AST node (e.g., AST::Quote)
2. Create handler (e.g., QuoteHandler)
3. Register handler in parser
4. Create renderer tag (e.g., QuoteTag)
5. Register tag in renderer
```

## Adding a New BBCode Tag

Let's walk through adding support for `[quote]` tags step by step.

### Step 1: Create AST Node

**File:** `lib/markbridge/ast/quote.rb`

```ruby
# frozen_string_literal: true

module Markbridge
  module AST
    class Quote < Element
      attr_reader :author

      def initialize(author: nil, children: [])
        @author = author
        super(children:)
      end
    end
  end
end
```

**Key points:**
- Extend `AST::Element` for container nodes
- Use keyword arguments for attributes
- Call `super(children:)` to initialize children array
- Add `attr_reader` for custom attributes (e.g., author)

### Step 2: Create Handler

**File:** `lib/markbridge/parsers/bbcode/handlers/quote_handler.rb`

```ruby
# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        class QuoteHandler < SimpleHandler
          def initialize
            super(AST::Quote, auto_closeable: false)
          end

          def create_element(token)
            # Get author from attribute or option
            author = token.attrs[:author] || token.attrs[:option]
            AST::Quote.new(author:)
          end
        end
      end
    end
  end
end
```

**Key points:**
- Extend `SimpleHandler` for basic tags
- Pass element class to `super`
- Set `auto_closeable: false` for block elements
- Override `create_element` to handle attributes
- Extract attributes from `token.attrs`

### Step 3: Register Handler

**Option A: Block-based configuration (recommended)**

```ruby
parser = Markbridge::Parsers::BBCode::Parser.new do |registry|
  registry.register("quote", QuoteHandler.new)
end
```

**Option B: Build from default**

```ruby
registry = Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |reg|
  reg.register("quote", QuoteHandler.new)
end

parser = Markbridge::Parsers::BBCode::Parser.new(handlers: registry)
```

**Option C: Add to default (for library maintainers)**

Edit `lib/markbridge/parsers/bbcode/handler_registry.rb`:

```ruby
def self.default
  new.tap do |registry|
    # ... existing registrations ...
    registry.register("quote", Handlers::QuoteHandler.new)
  end
end
```

### Step 4: Create Renderer Tag

**File:** `lib/markbridge/renderers/discourse/tags/quote_tag.rb`

```ruby
# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class QuoteTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            author = element.author ? " #{element.author}" : ""

            "[quote#{author}]\n#{content}\n[/quote]"
          end
        end
      end
    end
  end
end
```

**Key points:**
- Extend `Tag` base class
- Accept `element` and `interface` parameters
- Create child context with `interface.with_parent(element)`
- Render children with `interface.render_children`
- Return Markdown string

### Step 5: Register Renderer Tag

**Option A: Auto-registration (if following naming convention)**

```ruby
library = TagLibrary.new
library.auto_register! # Finds QuoteTag → AST::Quote

renderer = Renderer.new(tag_library: library)
```

**Option B: Manual registration**

```ruby
library = TagLibrary.default
library.register(AST::Quote, QuoteTag.new)

renderer = Renderer.new(tag_library: library)
```

**Option C: Add to default (for library maintainers)**

Edit `lib/markbridge/renderers/discourse/tag_library.rb`:

```ruby
def self.default
  new.tap do |library|
    # ... existing registrations ...
    library.register(AST::Quote, Tags::QuoteTag.new)
  end
end
```

### Auto-passthrough for unregistered AST classes

A custom AST class that has *no* Tag bound to it doesn't need a
"passthrough" Tag — `Renderer#render` falls through to
`render_children` automatically (see `lib/markbridge/renderers/discourse/renderer.rb`).
You only need to register a Tag when the class needs a non-trivial
rendering. To remove a built-in binding so this passthrough kicks in,
use `TagLibrary#unregister`:

```ruby
library.unregister(AST::Color)  # Color now renders as just its children
library.unregister(AST::Size)   # Size too
```

Or, more concisely, via the `Markbridge.discourse_renderer` factory:

```ruby
Markbridge.discourse_renderer(unregister: [AST::Color, AST::Size])
```

### Step 6: Add Requires

**File:** `lib/markbridge/ast.rb`

```ruby
require_relative "ast/quote"
```

**File:** `lib/markbridge/parsers/bbcode.rb`

```ruby
require_relative "bbcode/handlers/quote_handler"
```

**File:** `lib/markbridge/renderers/discourse.rb`

```ruby
require_relative "discourse/tags/quote_tag"
```

### Step 7: Test Your Tag

```ruby
require "markbridge/all"

# Parse BBCode
parser = Markbridge::Parsers::BBCode::Parser.new do |registry|
  registry.register("quote", QuoteHandler.new)
end

# Set up renderer
library = Markbridge::Renderers::Discourse::TagLibrary.default
library.register(AST::Quote, QuoteTag.new)
renderer = Markbridge::Renderers::Discourse::Renderer.new(tag_library: library)

# Test
bbcode = "[quote author=John]Hello world[/quote]"
ast = parser.parse(bbcode)
markdown = renderer.render(ast)

puts markdown
# => "[quote John]\nHello world\n[/quote]"
```

## Creating Custom Handlers

### Simple Formatting Handler

For basic formatting tags with no attributes:

```ruby
class MyFormatHandler < SimpleHandler
  def initialize
    super(AST::MyFormat, auto_closeable: true)
  end
end

# Register
registry.register(["myformat", "mf"], MyFormatHandler.new)
```

### Handler with Attributes

For tags that need to extract attributes:

```ruby
class ColorHandler < SimpleHandler
  def initialize
    super(AST::Color, auto_closeable: true)
  end

  def create_element(token)
    # Extract color from attribute or option
    color = token.attrs[:color] || token.attrs[:option]
    AST::Color.new(color:)
  end
end

# Usage: [color=red]text[/color] or [color color=red]text[/color]
```

### Self-Closing Handler

For tags that don't need closing:

```ruby
# Reuse built-in handler
handler = SelfClosingHandler.new(AST::MyElement)
registry.register("mytag", handler)

# Or create custom
class MyElementHandler < SelfClosingHandler
  def initialize
    super(AST::MyElement)
  end
end
```

### Raw Content Handler

For tags that capture unparsed content (like code blocks):

```ruby
class MyRawHandler < RawHandler
  def initialize
    super(AST::MyRaw)
  end

  def create_element(token, raw_content)
    # token: TagStartToken with attributes
    # raw_content: String of unparsed content
    lang = token.attrs[:lang] || token.attrs[:option]
    AST::MyRaw.new(language: lang, children: [AST::Text.new(raw_content)])
  end
end
```

### Custom Handler from Scratch

For complex behavior, extend `BaseHandler`:

```ruby
class CustomHandler < BaseHandler
  attr_reader :element_class

  def initialize
    @element_class = AST::Custom
  end

  def on_open(context:, token:, registry:)
    # Custom opening logic
    element = create_element(token)
    context.push_element(element)
    # Can modify state, look ahead, etc.
  end

  def on_close(token:, context:, registry:, tokens: nil)
    # Custom closing logic
    # Can use tokens for look-ahead
    registry.close_element(token:, context:, tokens:)
  end

  def auto_closeable?
    true # or false
  end

  private

  def create_element(token)
    AST::Custom.new(attrs: token.attrs)
  end
end
```

## Creating Custom Renderers

### Simple Tag

For tags that wrap content with markers:

```ruby
class MyFormatTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)
    interface.wrap_inline(content, "~~") # Custom markers
  end
end
```

### Tag with Attributes

For tags that use element attributes:

```ruby
class ColorTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)
    color = element.color || "inherit"

    # Render as HTML span
    "<span style=\"color: #{color}\">#{content}</span>"
  end
end
```

### Context-Aware Tag

For tags that behave differently based on parents:

```ruby
class SmartQuoteTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)

    # Check nesting depth
    depth = interface.count_parents(AST::Quote)

    if depth > 1
      # Nested quote - use different style
      "> #{content}"
    else
      # Top-level quote
      "[quote]\n#{content}\n[/quote]"
    end
  end
end
```

### Block Tag

For tags that render as blocks:

```ruby
class MyBlockTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)

    # Always render as block with blank lines
    "\n\n#{content}\n\n"
  end
end
```

### Self-Rendering Tag

For tags that don't have children:

```ruby
class IconTag < Tag
  def render(element, interface)
    # element.icon_name set during parsing
    ":#{element.icon_name}:"
  end
end
```

### Block-Based Tag

Register inline without creating a class:

```ruby
library.register(AST::Spoiler) do |element, interface|
  child_context = interface.with_parent(element)
  content = interface.render_children(element, context: child_context)
  "[spoiler]#{content}[/spoiler]"
end
```

## Plugin Pattern

Create reusable plugins that bundle parser and renderer extensions:

### Plugin Module

```ruby
module Markbridge
  module Plugins
    module Quote
      # AST Node
      class QuoteElement < AST::Element
        attr_reader :author

        def initialize(author: nil, children: [])
          @author = author
          super(children:)
        end
      end

      # Handler
      class QuoteHandler < Parsers::BBCode::Handlers::SimpleHandler
        def initialize
          super(QuoteElement, auto_closeable: false)
        end

        def create_element(token)
          author = token.attrs[:author] || token.attrs[:option]
          QuoteElement.new(author:)
        end
      end

      # Renderer Tag
      class QuoteTag < Renderers::Discourse::Tag
        def render(element, interface)
          child_context = interface.with_parent(element)
          content = interface.render_children(element, context: child_context)
          author = element.author ? " #{element.author}" : ""

          "[quote#{author}]\n#{content}\n[/quote]"
        end
      end

      # Plugin registration
      def self.register_parser(registry)
        registry.register("quote", QuoteHandler.new)
      end

      def self.register_renderer(library)
        library.register(QuoteElement, QuoteTag.new)
      end

      def self.register_all(parser_registry, renderer_library)
        register_parser(parser_registry)
        register_renderer(renderer_library)
      end
    end
  end
end
```

### Using the Plugin

```ruby
require "markbridge/all"
require "markbridge/plugins/quote"

# Configure parser
parser = Markbridge::Parsers::BBCode::Parser.new do |registry|
  Markbridge::Plugins::Quote.register_parser(registry)
end

# Configure renderer
library = Markbridge::Renderers::Discourse::TagLibrary.default
Markbridge::Plugins::Quote.register_renderer(library)
renderer = Markbridge::Renderers::Discourse::Renderer.new(tag_library: library)

# Use
bbcode = "[quote author=Jane]Hello[/quote]"
ast = parser.parse(bbcode)
markdown = renderer.render(ast)
```

### Plugin Collection

Create a registry of plugins:

```ruby
module Markbridge
  module Plugins
    class Registry
      def initialize
        @plugins = []
      end

      def register(plugin)
        @plugins << plugin
      end

      def configure_parser(parser_registry)
        @plugins.each { |plugin| plugin.register_parser(parser_registry) }
      end

      def configure_renderer(renderer_library)
        @plugins.each { |plugin| plugin.register_renderer(renderer_library) }
      end
    end
  end
end

# Usage
plugins = Markbridge::Plugins::Registry.new
plugins.register(Markbridge::Plugins::Quote)
plugins.register(Markbridge::Plugins::Color)
plugins.register(Markbridge::Plugins::Spoiler)

parser = Parser.new do |registry|
  plugins.configure_parser(registry)
end

library = TagLibrary.new
library.auto_register!
plugins.configure_renderer(library)
renderer = Renderer.new(tag_library: library)
```

## Advanced Examples

### Table Support

Complete example adding table support:

```ruby
# AST Nodes
class AST::Table < AST::Element
end

class AST::TableRow < AST::Element
end

class AST::TableCell < AST::Element
  attr_reader :header

  def initialize(header: false, children: [])
    @header = header
    super(children:)
  end
end

# Handlers
class TableHandler < SimpleHandler
  def initialize
    super(AST::Table, auto_closeable: false)
  end
end

class TableRowHandler < SimpleHandler
  def initialize
    super(AST::TableRow, auto_closeable: true)
  end

  def on_open(context:, token:, registry:)
    # Auto-close previous row
    if context.current_node.is_a?(AST::TableRow)
      context.pop_element
    end
    super
  end
end

class TableCellHandler < SimpleHandler
  def initialize
    super(AST::TableCell, auto_closeable: true)
  end

  def create_element(token)
    header = token.tag == "th"
    AST::TableCell.new(header:)
  end

  def on_open(context:, token:, registry:)
    # Auto-close previous cell
    if context.current_node.is_a?(AST::TableCell)
      context.pop_element
    end
    super
  end
end

# Renderer Tags
class TableTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    rows = element.children.map do |row|
      render_row(row, interface, child_context)
    end

    header_separator = build_header_separator(element.children.first)

    "\n\n#{rows[0]}\n#{header_separator}\n#{rows[1..].join("\n")}\n\n"
  end

  private

  def render_row(row, interface, context)
    row_context = context.with_parent(row)
    cells = row.children.map do |cell|
      cell_context = row_context.with_parent(cell)
      interface.render_children(cell, context: cell_context).strip
    end

    "| #{cells.join(" | ")} |"
  end

  def build_header_separator(header_row)
    cell_count = header_row.children.size
    "| " + (["---"] * cell_count).join(" | ") + " |"
  end
end

# Usage
parser = Parser.new do |registry|
  registry.register("table", TableHandler.new)
  registry.register("tr", TableRowHandler.new)
  registry.register(["td", "th"], TableCellHandler.new)
end

library = TagLibrary.new
library.register(AST::Table, TableTag.new)
# TableRow and TableCell handled by TableTag

renderer = Renderer.new(tag_library: library)

bbcode = <<~BBCODE
  [table]
  [tr][th]Name[th]Age
  [tr][td]Alice[td]30
  [tr][td]Bob[td]25
  [/table]
BBCODE

markdown = Markbridge.convert(bbcode, parser:, renderer:)
puts markdown
# | Name | Age |
# | --- | --- |
# | Alice | 30 |
# | Bob | 25 |
```

### Size/Font Tags

```ruby
class AST::Size < AST::Element
  attr_reader :size

  def initialize(size: nil, children: [])
    @size = size
    super(children:)
  end
end

class SizeHandler < SimpleHandler
  def initialize
    super(AST::Size, auto_closeable: true)
  end

  def create_element(token)
    size = token.attrs[:size] || token.attrs[:option]
    AST::Size.new(size:)
  end
end

class SizeTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)

    # Map size to Discourse notation or HTML
    size_map = {
      "small" => "<small>#{content}</small>",
      "large" => "<big>#{content}</big>",
      "huge" => "<h3>#{content}</h3>"
    }

    size_map[element.size] || content
  end
end

# Register
registry.register(["size", "font"], SizeHandler.new)
library.register(AST::Size, SizeTag.new)

# Usage: [size=large]Big text[/size]
```

### Align Tags

```ruby
class AST::Align < AST::Element
  attr_reader :alignment

  def initialize(alignment: "left", children: [])
    @alignment = alignment
    super(children:)
  end
end

class AlignHandler < SimpleHandler
  def initialize
    super(AST::Align, auto_closeable: false)
  end

  def create_element(token)
    # Get alignment from tag name or attribute
    alignment = case token.tag
                when "left" then "left"
                when "center" then "center"
                when "right" then "right"
                else token.attrs[:option] || "left"
                end

    AST::Align.new(alignment:)
  end
end

class AlignTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)

    # Discourse uses <div> for alignment
    "\n\n<div align=\"#{element.alignment}\">#{content}</div>\n\n"
  end
end

# Register
registry.register(["align", "left", "center", "right"], AlignHandler.new)
library.register(AST::Align, AlignTag.new)

# Usage: [center]Centered text[/center]
```

## Best Practices

### DO

✓ **Extend existing base classes** (`SimpleHandler`, `Tag`)
```ruby
class MyHandler < SimpleHandler
  # Reuse existing behavior
end
```

✓ **Use keyword arguments** for attributes
```ruby
def initialize(color: nil, children: [])
  @color = color
  super(children:)
end
```

✓ **Create child context** before rendering children
```ruby
child_context = interface.with_parent(element)
content = interface.render_children(element, context: child_context)
```

✓ **Set auto_closeable appropriately**
- `true` for inline formatting (bold, italic, etc.)
- `false` for block elements (lists, tables, etc.)

✓ **Extract attributes from token**
```ruby
value = token.attrs[:attr_name] || token.attrs[:option]
```

✓ **Test your extensions thoroughly**
- Unit tests for handlers
- Unit tests for tags
- Integration tests for full pipeline

✓ **Follow naming conventions** for auto-registration
- `BoldTag` → `AST::Bold`
- `QuoteTag` → `AST::Quote`

### DON'T

✗ **Don't mutate context**
```ruby
# Bad
context.add_parent(element)

# Good
child_context = interface.with_parent(element)
```

✗ **Don't forget to call super in initialize**
```ruby
# Bad
def initialize(color: nil, children: [])
  @color = color
  # Missing super!
end

# Good
def initialize(color: nil, children: [])
  @color = color
  super(children:)
end
```

✗ **Don't access renderer directly in tags**
```ruby
# Bad (old pattern)
renderer.render_children(element)

# Good (new pattern)
interface.render_children(element, context: child_context)
```

✗ **Don't skip creating child context**
```ruby
# Bad
content = interface.render_children(element, context: interface.context)

# Good
child_context = interface.with_parent(element)
content = interface.render_children(element, context: child_context)
```

✗ **Don't hardcode indentation/spacing**
```ruby
# Bad
"  #{content}" # Fixed 2 spaces

# Good
depth = interface.count_parents(AST::List)
"#{' ' * (depth * 2)}#{content}"
```

✗ **Don't forget frozen_string_literal comment**
```ruby
# Always start files with:
# frozen_string_literal: true
```

### Performance Tips

- Use `SimpleHandler` when possible (optimized)
- Keep `create_element` fast (called for every tag)
- Avoid excessive string allocations in renderers
- Use `wrap_inline` helper (handles fallbacks)
- Cache expensive lookups in handler initialize

### Testing Your Extensions

```ruby
RSpec.describe QuoteHandler do
  let(:handler) { described_class.new }
  let(:registry) { double("registry") }
  let(:context) { double("context") }

  describe "#create_element" do
    it "creates Quote with author from attribute" do
      token = TagStartToken.new("quote", { author: "John" })
      element = handler.create_element(token)

      expect(element).to be_a(AST::Quote)
      expect(element.author).to eq("John")
    end

    it "uses option attribute as fallback" do
      token = TagStartToken.new("quote", { option: "Jane" })
      element = handler.create_element(token)

      expect(element.author).to eq("Jane")
    end
  end
end

RSpec.describe QuoteTag do
  let(:tag) { described_class.new }

  describe "#render" do
    it "renders quote with author" do
      element = AST::Quote.new(author: "John", children: [
        AST::Text.new("Hello")
      ])

      interface = double("interface")
      allow(interface).to receive(:with_parent).and_return(double("context"))
      allow(interface).to receive(:render_children).and_return("Hello")

      result = tag.render(element, interface)

      expect(result).to eq("[quote John]\nHello\n[/quote]")
    end
  end
end
```

## Next Steps

- **[BBCode Parser Guide](parsers/bbcode.md)** - Deep dive into parsing
- **[Discourse Renderer Guide](renderers/discourse.md)** - Learn about rendering
- **[Architecture Overview](architecture.md)** - Understand the pipeline
- **[Performance Guide](performance.md)** - Optimize your extensions
