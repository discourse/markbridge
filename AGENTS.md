# AGENTS.md - AI Assistant Guide for Markbridge

Quick reference guide for AI assistants working on the Markbridge codebase.

## Project Overview

**Markbridge** converts BBCode to Discourse-flavored Markdown using a **Parse → AST → Render** pipeline.

**Design Philosophy:**
- Graceful degradation (unknown tags preserved, no exceptions)
- Performance-conscious (O(n) parsing, minimal allocations)
- Extensible (Handler and Tag registries)
- Clean separation (parsing ↔ rendering via AST)
- Test-driven (unit, integration, system tests)

## Core Architecture

```
BBCode Input → Parser → AST → Renderer → Markdown Output
```

### Three-Phase Pipeline

1. **Parser** (`lib/markbridge/parsers/bbcode/`)
   - Scanner: Tokenizes input → `TextToken`, `TagStartToken`, `TagEndToken`
   - Handlers: Convert tokens → AST nodes
   - Closing Strategies: Handle tag closing (Strict, Reordering)

2. **AST** (`lib/markbridge/ast/`)
   ```
   Node (base)
   ├── Text (leaf)
   ├── LineBreak, HorizontalRule (leaf)
   └── Element (container)
       ├── Document (root)
       ├── Formatting: Bold, Italic, Underline, Strikethrough
       └── Complex: Code, List, ListItem, Url
   ```
   - Adjacent Text nodes auto-merge
   - Children validated as `AST::Node`

3. **Renderer** (`lib/markbridge/renderers/discourse/`)
   - Walks AST, dispatches to Tags via TagLibrary
   - RenderContext: Immutable parent chain for context-aware rendering
   - RenderingInterface: Abstraction layer between tags and renderer

## Key Patterns

### Registry Pattern (Extensibility)

**Parser customization:**
```ruby
parser = Markbridge::Parsers::BBCode::Parser.new do |registry|
  registry.register("quote", QuoteHandler.new)
end
```

**Renderer customization:**
```ruby
library = Markbridge::Renderers::Discourse::TagLibrary.new
library.register(AST::Bold, BoldTag.new)
# Or use auto_register! for convention-based discovery
```

### Strategy Pattern (Closing Strategies)

Two strategies for closing tags:
- **Strict**: Auto-close only, no reordering
- **Reordering**: Look-ahead for matching sequences (default)

Set via: `registry.closing_strategy = ClosingStrategies::Reordering.new`

### Visitor Pattern (Rendering)

Tags receive `(element, interface)` where interface provides:
- `render_children(element, context:)`
- `with_parent(element)` - immutable context chaining
- `find_parent(klass)`, `count_parents(klass)`, `has_parent?(klass)`
- `wrap_inline(content, markers)`

## Module Structure

```ruby
Markbridge
  ├── AST: Node, Element, Text, Bold, Italic, Code, List, etc.
  ├── Parsers::BBCode
  │   ├── Parser, Scanner, ParserState, HandlerRegistry
  │   ├── Tokens: Token, TextToken, TagStartToken, TagEndToken
  │   ├── Handlers: Base, Simple, Raw, SelfClosing, Url, List, ListItem
  │   └── ClosingStrategies: Base, Strict, Reordering, TagReconciler
  └── Renderers::Discourse
      ├── Renderer, TagLibrary, RenderContext, RenderingInterface, Tag
      └── Tags: Bold, Italic, Code, List, etc.
```

## Critical Conventions

1. **Frozen string literal**: ALWAYS start files with `# frozen_string_literal: true`
2. **Keyword arguments**: Use for all methods with multiple params
3. **Immutability**: Use `attr_reader`, not `attr_accessor`
4. **Type checking**: Validate at boundaries
5. **Single responsibility**: Keep classes focused
6. **NO monkey patching**: Don't modify Ruby core classes
7. **Private methods**: Use `private`, not `protected` (Ruby best practice)

## Adding New Tags

**Quick steps:**
1. Create AST node: `lib/markbridge/ast/quote.rb`
2. Create handler: `lib/markbridge/parsers/bbcode/handlers/quote_handler.rb`
3. Register in `HandlerRegistry.default` (lib/markbridge/parsers/bbcode/handler_registry.rb)
4. Create tag: `lib/markbridge/renderers/discourse/tags/quote_tag.rb`
5. Register in `TagLibrary.default` OR use auto_register! for convention-based discovery
6. Add requires to loader files
7. Decide on html_mode behavior (see below)
8. Write tests (unit + integration)

### html_mode contract

`RenderContext#html_mode?` is `true` when a tag is rendering inside a
CommonMark HTML block (currently triggered by `TableTag`'s HTML fallback
for uneven rows, multi-line cells, or nested tables). Per [CommonMark
§4.6](https://spec.commonmark.org/0.31.2/#html-blocks), content inside
the block is treated as raw HTML and is not re-parsed for Markdown
except across blank lines. Every tag must pick one of two forms when
`interface.html_mode?` is true:

1. **Raw HTML** — emit an HTML equivalent (`<strong>` for `**`,
   `<ul><li>` for `- `, etc.). HTML-escape any user-controlled string
   that ends up as attribute or element content via `HtmlEscaper`. The
   output is spliced verbatim into the surrounding block. Prefer this
   form when the tag has a natural HTML representation.

2. **Markdown island** — wrap the tag's normal Markdown output in
   `\n\n…\n\n`. The blank lines close the HTML block; CommonMark parses
   the inner content as Markdown; the next blank line re-opens the
   block. Cost: blank-line wrapping forces a `<p>` margin around
   inline content, so use this form only for tags with no clean HTML
   equivalent (e.g. `EventTag`/`PollTag` stubs that defer rendering to
   downstream BBCode plugins).

`spec/integration/markbridge/renderers/discourse/html_mode_contract_spec.rb`
enforces this structurally: every registered tag is rendered in
`html_mode` and the output is checked for raw Markdown sigils.

**See `examples/` for complete examples.**

## Development Workflow

### Setup
```bash
bundle install
bin/setup
```

### Common Commands
```bash
# ALWAYS use bundle exec for gem commands (except bin/* scripts)
bundle exec rake              # Run tests (default)
bundle exec rubocop           # Lint Ruby/RSpec (VerifiedDoubles enabled)
bundle exec rspec             # Run all tests
bundle exec rspec spec/unit/  # Run unit tests
bin/lint                      # Auto-fix style (RuboCop + Syntax Tree)
bin/rubycritic                # Run tests with coverage + RubyCritic analysis
```

### Pre-commit
**CRITICAL**: Run `bin/lint` before creating any PR.

Lefthook runs on commit:
- RuboCop linting
- Syntax Tree formatting
- RBS syntax check

## Testing

**Three-tier approach:**
- **Unit tests** (`spec/unit/`): Test classes in isolation, mirror lib/ structure
- **Integration tests** (`spec/integration/`): Test component interactions
- **System tests** (`spec/system/`): End-to-end BBCode → Markdown

**Custom matchers** (`spec/support/matchers/`):
```ruby
expect(token).to match_text_token("text")
expect(token).to match_tag_start("b", option: "value")
expect(token).to match_tag_end("b")
```

**Best practices:**
- Test public APIs, not private methods
- Use `described_class` instead of hardcoded names
- Keep tests independent (random order execution)
- Use `expect`, never `should`

## Mutation Testing — markbridge-specific

- Project wrapper is `bin/mutant`, not `bundle exec mutant`.
- Line coverage must not regress. Capture baseline with
  `COVERAGE=1 bin/rspec` before changes; re-run after to compare.
- Test through the public API only. No `send`/`__send__` to reach
  private methods, and no test-only subclasses that publicize them
  (`Class.new(described_class) { public :helper }`). Both couple the
  tests to internal structure and defeat the point of `private`. If a
  mutation is only observable by calling a private method directly,
  add it to the `mutant.yml` ignore list (with the required comment
  from the skill) — don't reach behind the curtain.
- No stubbing or mocking the SUT (the class currently being mutated).
- `MarkdownEscaper` is a hot path. Benchmark (`bundle exec ruby --yjit /tmp/bench_escaper.rb`)
  before/after any change to `lib/markbridge/renderers/discourse/markdown_escaper.rb`.
  Tests over refactors when behavior is equivalent.
- When writing a `mutant.yml` `ignore` entry per the skill's
  "Unkillable" flow, the inline comment must name the specific
  mutation that survived and summarize what was tried.

**Commit flow (per the skill): code changes and test changes go in
separate commits — test first, code-simplification second. Don't mix.
Tests-only changes can be one commit.**

## Performance Notes

**Scanner** (performance-critical):
- Use index-based access: `@input[@pos]`, not `@input[@pos..@pos]`
- Bounded backtracking: save position, restore on failure
- Minimize allocations: reuse strings
- Regex only for character classes

**AST**:
- Text nodes auto-merge (reduces tree size)

**Renderer**:
- RenderContext uses hash-based cache (O(1) parent lookups)
- Single-pass tree traversal
- In-memory rendering (stream large documents yourself)

## Quick Reference

### Extension Points

| What | Where | How |
|------|-------|-----|
| Add BBCode tag | HandlerRegistry | Create handler + register |
| Customize rendering | TagLibrary | Create tag + register (or auto_register!) |
| Change closing behavior | Parser | Set closing_strategy |
| Add custom AST node | `lib/markbridge/ast/` | Extend Node/Element |

### Key Files

| Component | Location |
|-----------|----------|
| AST nodes | `lib/markbridge/ast/*.rb` |
| Parser | `lib/markbridge/parsers/bbcode/parser.rb` |
| Handlers | `lib/markbridge/parsers/bbcode/handlers/*.rb` |
| Handler registry | `lib/markbridge/parsers/bbcode/handler_registry.rb` |
| Renderer | `lib/markbridge/renderers/discourse/renderer.rb` |
| Tags | `lib/markbridge/renderers/discourse/tags/*.rb` |
| Tag library | `lib/markbridge/renderers/discourse/tag_library.rb` |

### Constants

| Constant | Value | Location |
|----------|-------|----------|
| MAX_DEPTH | 100 | ParserState |
| MAX_AUTO_CLOSE_DEPTH | 5 | ClosingStrategies::Base |
| MAX_PEEK_AHEAD | 5 | ClosingStrategies::Reordering |

## Important Notes for AI Assistants

1. **NO backward compatibility needed** - Make breaking changes freely to improve architecture
2. **Handler registration** - Only pass `tag_names` and `handler` (handler knows `auto_closeable?` and `element_class`)
3. **element_class is public** - Access via `handler.element_class`, not `send(:element_class)`
4. **Tag signature** - Tags accept `(element, interface)`, not `(element, renderer, context:)`
5. **Dependency order** - Load base classes before subclasses in require statements
6. **Always read code first** - NEVER propose changes to code you haven't read
7. **Set is core** - On Ruby 3.2+ `Set` is built-in; no need to `require "set"`
8. **Verified doubles** - Use `instance_double` (or other verified doubles) instead of `double` to satisfy `RSpec/VerifiedDoubles`

## Documentation

- **This file**: Quick reference and architecture
- **README.md**: User-facing quick start
- **docs/architecture.md**: System architecture and design patterns
- **docs/parsers/**: BBCode, HTML, and TextFormatter parser guides
- **docs/renderers/**: Discourse renderer guide
- **docs/extending.md**: How to add custom tags and handlers
- **docs/performance.md**: Performance optimization guide
- **examples/**: Runnable code examples
- **spec/**: Executable documentation (tests show expected behavior)

---

**Maintenance**: This file should be updated when core architecture changes. Details that change frequently (file counts, specific line numbers, step-by-step tutorials) are intentionally excluded. Point to examples/ and spec/ for those.

**Last Updated**: 2025-11-26
**Version**: 0.1.0
