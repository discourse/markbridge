# Architecture Overview

Markbridge uses a clean three-phase pipeline to convert BBCode to Markdown. This document explains the high-level architecture, design patterns, and how the components work together.

## Table of Contents

- [Three-Phase Pipeline](#three-phase-pipeline)
- [Component Overview](#component-overview)
- [Design Patterns](#design-patterns)
- [Data Flow](#data-flow)
- [Design Philosophy](#design-philosophy)

## Three-Phase Pipeline

Markbridge follows a **Parse → AST → Render** architecture:

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   BBCode    │  →   │     AST     │  →   │  Markdown   │
│   Input     │      │    Tree     │      │   Output    │
└─────────────┘      └─────────────┘      └─────────────┘
      │                     │                     │
   Parser              Document              Renderer
   Scanner               Nodes                  Tags
   Handlers             Elements              Context
   Registry                                   Library
```

Between the AST and Render, an optional `Markbridge::Normalizer` pass
rewrites the tree so the renderer is only handed markup the target format
can express (no link inside a link, no block inside an inline container,
etc.). It runs by default at the conversion level; the three components
above are unchanged by it. See [AST Normalization](normalization.md).

### Phase 1: Parsing (BBCode → AST)

**Purpose:** Convert BBCode text into a structured tree

**Components:**
- **Scanner** - Tokenizes input into `TextToken`, `TagStartToken`, `TagEndToken`
- **Parser** - Orchestrates scanning and delegates to handlers
- **Handlers** - Convert tokens to AST nodes based on tag type
- **HandlerRegistry** - Maps tag names to handlers
- **ParserState** - Manages parsing state (node stack, depth tracking)
- **Closing Strategies** - Handle closing tag logic (Strict, Reordering)

**Example:**
```ruby
"[b]Hello[/b]"
  → Scanner → [TagStart(b), Text("Hello"), TagEnd(b)]
  → Handlers → AST::Bold([AST::Text("Hello")])
```

### Phase 2: AST (Abstract Syntax Tree)

**Purpose:** Represent document structure independent of input/output formats

**Node Hierarchy:**
```
Node (empty base class)
├── Text (leaf node containing text)
└── Element (container with children)
    ├── Document (root element)
    ├── Formatting: Bold, Italic, Underline, Strikethrough
    ├── Complex: Code, List, ListItem, Url
    └── Self-closing: LineBreak, HorizontalRule
```

**Key Features:**
- **Renderer-agnostic** - AST doesn't know about Markdown or any output format
- **Text merging** - Adjacent `Text` nodes automatically merge for efficiency
- **Type safety** - All children validated as `AST::Node` instances
- **Immutable** - No public setters after construction

### Phase 3: Rendering (AST → Markdown)

**Purpose:** Convert AST tree into Discourse-flavored Markdown

**Components:**
- **Renderer** - Walks AST tree and generates output
- **TagLibrary** - Maps AST node classes to Tag renderers
- **Tags** - Render specific AST nodes to Markdown
- **RenderingInterface** - Abstraction layer between tags and renderer
- **RenderContext** - Tracks parent chain for context-aware rendering

**Example:**
```ruby
AST::Bold([AST::Text("Hello")])
  → TagLibrary[AST::Bold] → BoldTag
  → interface.wrap_inline("Hello", "**")
  → "**Hello**"
```

## Component Overview

### Parser Components

#### Scanner (`Markbridge::Parsers::BBCode::Scanner`)

**Responsibility:** Stream characters and produce tokens

**Key Methods:**
- `next_token` - Returns next token or nil at end of input
- Character-by-character streaming with minimal allocations

**Token Types:**
- `TextToken` - Plain text content
- `TagStartToken` - Opening tag like `[b]` with attributes
- `TagEndToken` - Closing tag like `[/b]`

#### Parser (`Markbridge::Parsers::BBCode::Parser`)

**Responsibility:** Orchestrate parsing and build AST

**Key Methods:**
- `parse(input)` - Main entry point, returns `AST::Document`
- `unknown_tags` - Hash of unrecognized tags encountered

**Features:**
- Normalizes line endings before parsing
- Delegates token processing to handlers
- Tracks unknown tags for debugging

#### Handlers

**Responsibility:** Convert specific tag types to AST nodes

**Types:**
- **SimpleHandler** - Formatting tags (bold, italic, etc.)
- **RawHandler** - Code blocks that don't parse inner BBCode
- **SelfClosingHandler** - Line breaks, horizontal rules
- **UrlHandler** - Links with URL attributes
- **ListHandler** - Ordered/unordered lists
- **ListItemHandler** - List items with auto-closing

**Base Interface:**
```ruby
class BaseHandler
  attr_reader :element_class

  def on_open(context:, token:, registry:)
    # Called when opening tag encountered
  end

  def on_close(token:, context:, registry:, tokens: nil)
    # Called when closing tag encountered
  end

  def auto_closeable?
    # Whether this tag can be auto-closed
  end
end
```

#### HandlerRegistry

**Responsibility:** Map tag names to handlers

**Key Features:**
- Tag name normalization and caching
- Auto-closeable element tracking
- Element class to handler mapping
- Configurable closing strategy

**Usage:**
```ruby
# Block-based configuration (recommended)
parser = Parser.new do |registry|
  registry.register("quote", QuoteHandler.new)
end

# Or customize default registry
registry = HandlerRegistry.build_from_default do |reg|
  reg.register("custom", CustomHandler.new)
end
```

#### Closing Strategies

**Responsibility:** Handle mismatched or out-of-order closing tags

**Types:**
- **Strict** - Auto-close only, no reordering
- **Reordering** - Look-ahead to match closing sequences (default)

**Key Limits:**
- Max auto-close depth: 5 levels
- Max peek-ahead: 5 tokens

### AST Components

#### Node (`Markbridge::AST::Node`)

**Base class for all AST nodes** (empty marker class)

#### Text (`Markbridge::AST::Text`)

**Leaf node containing text content**

```ruby
text = AST::Text.new("Hello")
text.text # => "Hello"
text.append(" World") # Mutate existing text
```

#### Element (`Markbridge::AST::Element`)

**Container node with children**

**Key Features:**
- Automatically merges adjacent `Text` nodes
- Type validation for children
- Immutable after construction

```ruby
element = AST::Bold.new
element << AST::Text.new("Hello")
element << AST::Text.new(" World")
# Result: One Text node with "Hello World"
```

#### Document (`Markbridge::AST::Document`)

**Root element of the AST tree**

Always the top-level node returned by parser.

#### Self-closing Nodes (`Markbridge::AST::LineBreak`, `Markbridge::AST::HorizontalRule`)

**Leaf nodes without children**

These inherit directly from `AST::Node` (not `Element`) and cannot accept children. They are typically produced by self-closing tags like `[br]` and `[hr]`.

### Renderer Components

#### Renderer (`Markbridge::Renderers::Discourse::Renderer`)

**Responsibility:** Walk AST and generate Markdown

**Key Methods:**
- `render(node, context:)` - Main entry point
- Dispatches to tags based on node class
- Normalizes final output spacing

**Types:**
- **Renderer** - In-memory rendering (outputs complete string)

#### RenderingInterface

**Responsibility:** Decouple tags from renderer implementation

**Provides to tags:**
- `render_children(element, context:)` - Render child nodes
- `with_parent(element)` - Create child context
- `find_parent(klass)` - O(1) parent lookup via cache
- `count_parents(klass)` - Count ancestors of type
- `has_parent?(klass)` - Check for ancestor
- `wrap_inline(content, markers)` - Smart marker wrapping
- `block_context?(element)` - Check if block or inline

**Benefits:**
- Tags don't depend on specific renderer
- Enables streaming rendering
- Simplifies testing
- Clear API contract

#### TagLibrary

**Responsibility:** Map AST node classes to Tag renderers

**Key Features:**
- Auto-registration by naming convention
- Fallback to default tag for unknown nodes
- Block-based tag registration

**Auto-Registration:**
```ruby
library = TagLibrary.new
library.auto_register!
# Discovers: BoldTag → AST::Bold, ItalicTag → AST::Italic, etc.
```

#### Tags

**Responsibility:** Render specific AST nodes

**Interface:**
```ruby
class Tag
  def render(element, interface)
    # Returns Markdown string
  end
end
```

**Built-in Tags:**
- `BoldTag`, `ItalicTag`, `StrikethroughTag`, `UnderlineTag`
- `CodeTag`, `ListTag`, `ListItemTag`
- `UrlTag`, `HorizontalRuleTag`

#### RenderContext

**Responsibility:** Track parent chain for context-aware rendering

**Key Features:**
- **Immutable** - Creates new context instead of mutating
- **Cached lookups** - O(1) parent finding via hash cache
- **Parent tracking** - Maintains full ancestor chain

**Usage:**
```ruby
# Check if nested in list
if interface.has_parent?(AST::List)
  # Render differently
end

# Count nesting level
depth = interface.count_parents(AST::List)
indent = "  " * depth
```

## Design Patterns

### 1. Composite Pattern (AST)

Elements contain children forming a tree structure.

```ruby
document = AST::Document.new
bold = AST::Bold.new
bold << AST::Text.new("Hello")
document << bold
```

**Benefits:**
- Uniform interface for all nodes
- Easy tree traversal
- Flexible nesting

### 2. Strategy Pattern (Closing Strategies)

Different algorithms for handling closing tags.

```ruby
# Strict strategy
parser = Parser.new(closing_strategy: :strict)

# Reordering strategy (default)
parser = Parser.new(closing_strategy: :reordering)
```

**Benefits:**
- Pluggable behavior
- Easy to test separately
- User can choose tradeoffs

### 3. Registry Pattern (Extensibility)

Registries map tags to handlers and AST nodes to renderers.

```ruby
# Parser: HandlerRegistry
registry.register("quote", QuoteHandler.new)

# Renderer: TagLibrary
library.register(AST::Quote, QuoteTag.new)
```

**Benefits:**
- Decouples tag definitions from core
- Easy to add custom tags
- No modification of core classes

### 4. Visitor Pattern (Rendering)

Renderer visits AST nodes, dispatching to appropriate tags.

```ruby
def render(node, context)
  case node
  when Element
    tag = tag_library[node.class]
    interface = RenderingInterface.new(self, context)
    tag.render(node, interface)
  when Text
    node.text
  end
end
```

**Benefits:**
- Separation of tree structure from operations
- Easy to add new renderers
- Single dispatch point

### 5. Immutable Context Pattern

RenderContext creates new instances instead of mutating.

```ruby
def with_parent(element)
  self.class.new(parents: [@parents, element].flatten)
end
```

**Benefits:**
- No side effects during rendering
- Safe for concurrent rendering
- Clear parent tracking

### 6. Builder Pattern (List Items)

ListItemFormatter builds formatted output incrementally.

```ruby
formatter = ListItemFormatter.new(content: "Item", depth: 0)
formatter.with_marker("- ")
formatter.with_trailing_newline
formatted = formatter.build
```

**Benefits:**
- Flexible construction
- Clear intent
- Easy to test

## Data Flow

### Complete Example

**Input:** `[b]Hello [i]world[/i]![/b]`

**Phase 1: Scanning**
```
Scanner produces:
  1. TagStartToken(tag: "b")
  2. TextToken(text: "Hello ")
  3. TagStartToken(tag: "i")
  4. TextToken(text: "world")
  5. TagEndToken(tag: "i")
  6. TextToken(text: "!")
  7. TagEndToken(tag: "b")
```

**Phase 2: Parsing**
```
Handler operations:
  1. SimpleHandler(Bold) → Push AST::Bold
  2. Append AST::Text("Hello ")
  3. SimpleHandler(Italic) → Push AST::Italic
  4. Append AST::Text("world")
  5. SimpleHandler(Italic) → Pop AST::Italic
  6. Append AST::Text("!")
  7. SimpleHandler(Bold) → Pop AST::Bold

Result AST:
  Document
    └─ Bold
        ├─ Text("Hello ")
        ├─ Italic
        │   └─ Text("world")
        └─ Text("!")
```

**Phase 3: Rendering**
```
Rendering walk:
  1. Renderer visits Document → render children
  2. Visit Bold → BoldTag.render
     a. Create child context with Bold as parent
     b. Render children: "Hello " + "*world*" + "!"
     c. Wrap with **: "**Hello *world*!**"
  3. Return final: "**Hello *world*!**"
```

### Error Handling Flow

**Unknown Tag:** `[unknown]text[/unknown]`
```
1. Scanner: TagStartToken(tag: "unknown")
2. Parser: No handler found → unknown_tags["unknown"] = 1
3. Parser: Skip wrapper, continue parsing children
4. TextToken("text") → Text("text")
5. TagEndToken("unknown") → unknown_tags["unknown"] = 2
6. Result: Text("text")
```

**Mismatched Tags:** `[b][i]text[/b][/i]`
```
1. Parse [b] → Push Bold
2. Parse [i] → Push Italic
3. Parse [/b] → Expected [/i], got [/b]
4. Closing strategy:
   - Reordering: Look ahead, find [/i]
   - Match sequence: [italic, bold] == [italic, bold]
   - Consume both closers, pop both elements
5. Result: Bold(Italic(Text("text")))
```

## Design Philosophy

### Graceful Degradation

Unknown tags don't crash parsing—they're ignored while processing their children:

```ruby
parser = Parser.new
ast = parser.parse("[unknown]text[/unknown]")
# Result: Text("text")
# parser.unknown_tags => {"unknown" => 2}
```

### Performance-Conscious

- **O(n) parsing** - Single pass through input
- **Minimal allocations** - Reuse buffers where possible
- **Bounded operations** - Depth limits prevent runaway behavior
- **Smart caching** - Parent lookups cached in context

### Extensible

- **Registry pattern** - Add handlers without modifying core
- **Tag library** - Custom renderers for any AST node
- **Strategy pattern** - Pluggable closing behavior
- **Clean interfaces** - Well-defined extension points

### Clean Separation

- **Parser doesn't know about Markdown** - Only builds AST
- **Renderer doesn't know about BBCode** - Only walks AST
- **AST is format-agnostic** - Can add HTML renderer, etc.
- **Tags don't know about renderer** - Only use interface

### Test-Driven

- **Unit tests** - Individual classes in isolation
- **Integration tests** - Component interactions
- **System tests** - Full BBCode → Markdown flows
- **Executable documentation** - Tests show expected behavior

## Next Steps

- **[BBCode Parser Guide](parsers/bbcode.md)** - Deep dive into parsing BBCode
- **[Discourse Renderer Guide](renderers/discourse.md)** - Learn about rendering to Markdown
- **[Extending Markbridge](extending.md)** - Add custom tags
- **[Performance Guide](performance.md)** - Optimization tips
