# AGENTS.md - AI Assistant Guide for Markbridge

Quick reference guide for AI assistants working on the Markbridge codebase.

## Project Overview

**Markbridge** converts BBCode, HTML, MediaWiki, and s9e TextFormatter XML to Markdown using a **Parse → AST → Render** pipeline. The shipped renderer produces Discourse-flavored Markdown. The parsers and AST are renderer-agnostic.

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

Tags receive `(element, interface)` and return finished Markdown, or
inline tokens (`Inline::Tokens`) that the renderer's
`Inline::Serializer` writes with the neighbors in view: marker
placement, HTML fallbacks, bare URLs, joins and the html_mode form
live there. The interface provides:
- `render_children(element, context:)` - the children as Markdown
- `render_tokens(element, context:)` - the children as inline tokens
- `render_default(node)` - stock rendering, bypassing tag overrides
  (lets a custom tag intercept only the nodes it cares about)
- `with_parent(element)` - immutable context chaining
- `find_parent(klass)`, `count_parents(klass)`, `has_parent?(klass)`
- `previous_sibling(element)`, `next_sibling(element)`,
  `sibling(element, offset:)` - the neighbors among the children of
  the parent
- `previous_list(element)` - the last list in front, with nothing
  visible between

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
   (a block tag returns a String; an inline tag whose markers depend on
   the neighbors returns `Inline::Tokens`, see `BoldTag`)
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
except across blank lines. A tag that returns inline tokens leaves
html_mode to the serializer. Every tag that returns a String must pick
one of two forms when `interface.html_mode?` is true:

1. **Raw HTML** — emit an HTML equivalent (`<strong>` for `**`,
   `<ul><li>` for `- `, etc.). HTML-escape any user-controlled string
   that ends up as attribute or element content via `HtmlEscaper`. The
   output is spliced verbatim into the surrounding block. Prefer this
   form when the tag has a natural HTML representation.

2. **Markdown island** — wrap the tag's normal Markdown output in
   `\n\n…\n\n` via `HtmlBlock.island`. The blank lines close the HTML
   block; CommonMark parses the inner content as Markdown; the next
   blank line re-opens the block. Cost: blank-line wrapping forces a
   `<p>` margin around inline content, so use this form only for tags
   with no clean HTML equivalent (e.g. `EventTag`/`PollTag` stubs that
   defer rendering to downstream BBCode plugins).

`Markbridge::Renderers::Discourse::HtmlBlock` owns everything about
HTML blocks: `island` builds the wrap, `opens?` says whether a line
starts a block (`ListItemTag` asks before it drops a blank line in
front of a nested list), and `safe?` is the check the contract spec
runs. `AlignTag` uses the island form outside html_mode too, because
its own `<div>` opens a block.

`spec/integration/markbridge/renderers/discourse/html_mode_contract_spec.rb`
enforces this structurally: every registered tag is rendered in
`html_mode` and the output is checked for raw Markdown sigils. The
check ships as a shared RSpec example (`require "markbridge/rspec"`,
then `it_behaves_like "an html_mode safe tag"`), so consumer projects
can run it against their own tags.

**See `docs/src/content/docs/customization/extending.md` for complete examples.**

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

**Round-trip checks against a Markdown parser**:
- `spec/integration/markbridge/commonmark_roundtrip_spec.rb` takes the
  expected HTML of every CommonMark spec example, converts it with the
  HTML parser and the renderer, cooks the Markdown with markdown-it and
  compares the result with the HTML it started from. An example that
  does not round-trip is listed in `INTENDED_DIFFERENCES` or
  `KNOWN_BUGS` with a reason. The spec fails when a listed example
  starts to pass, so a bug fix removes its entry in the same commit.
- `RoundTripChecker` (`spec/support/round_trip_checker.rb`) renders an
  AST, cooks it and compares the cooked HTML with the AST in four ways:
  the structure (lists, items, quotes, code, links, emphasis, headings),
  the visible text, the link and image destinations, and tight lists
  (an item with inline content only must not cook with a `<p>`). It
  cooks with markdown-it (see below). On a failure `explain` shrinks the
  AST with `AstShrinker` as long as the same check fails and prints the
  AST, the Markdown and the cooked HTML. The two specs below use it.
- `spec/integration/markbridge/renderers/discourse/structure_roundtrip_spec.rb`
  builds nested documents with `AstGenerator` (`spec/support/`) from a
  seed: every block and inline node kind the renderer has a tag for
  (lists, quotes, tables, details, aligned blocks, headings, code,
  emphasis, links, images, uploads, mentions, ...), with text made of
  words, words with one of the adjacency character classes spliced in,
  tricky tokens and lines from the CommonMark spec. 300 seeds by
  default; `STRUCTURE_SEEDS=3000 bundle exec rspec <file>` runs more. A
  construct the generator leaves out because of an open bug is marked
  with a comment that names the bug; the fix removes the exclusion.
- `spec/integration/markbridge/renderers/discourse/adjacency_roundtrip_spec.rb`
  puts two nodes next to each other on purpose (`AdjacencyGenerator`):
  every inline node kind with every character class at the edge that
  faces its neighbor, in nine positions (in a paragraph, at the start
  or the end of a line, after a block, in strong emphasis, in a heading,
  in a list item, in a link label, in a quote), and block pairs (two
  lists with whitespace, a line break or an empty element between them,
  a list followed by text in an item, ...). CI runs a fixed sample of
  2000 of the 1,279,137 inline pairs (`ADJACENCY_SAMPLE=N` changes the size)
  plus every block pair. A case id names the case:
  `paragraph/text(*)+bold(a)` or `blocks/item/ul+space+ul`.
- `spec/support/round_trip_known_bugs.rb` lists the cases and seeds that
  fail today, with a reason. Both specs
  run every listed case and fail when it starts to pass, so a fix
  removes the entry in the same commit. A new failure that is not fixed
  right away gets an entry there, not an exclusion in a generator.
- `bin/fuzz-render` runs every inline pair, every block pair and as many
  seeds as asked for outside RSpec (`--only pairs|blocks|trees`,
  `--sample N`, `--seeds N`, `--all` to run the known bugs too). Every
  failure is shrunk, and failures whose shrunk trees have the same shape
  are one group with one report, so a long run reads as a short list of
  distinct bugs; `--output DIR` writes the reports to a file. The
  nightly `fuzz-render.yml` workflow runs it and uploads the reports
  when a case fails.
- When a test is about structure (nesting, blank lines, indentation),
  assert on the cooked HTML (`spec/support/cooked_output.rb`), not on
  the exact Markdown string. A Markdown expectation written from the
  current output also fixes the current bug in place.

**Cooking with markdown-it** (needs Node 22; `bin/setup` runs `npm ci
--prefix spec/support/markdown_it`):
- Every spec that cooks Markdown cooks with markdown-it, which is what
  Discourse cooks with. `MarkdownItCooker`
  (`spec/support/markdown_it_cooker.rb`) sends the Markdown to one
  long-running `node spec/support/markdown_it/cook.mjs`, which sets up
  markdown-it like Discourse with its default site settings. There is
  no second parser: cmark-gfm reads some Markdown differently (it keeps
  less after a bare URL in the link, reads a single `~` as
  strikethrough, keeps a single newline a soft break), and output tuned
  to it was not output tuned to Discourse.
- Without Node or `node_modules` the cooked examples are skipped.
  `MARKDOWN_IT_REQUIRED=1` turns that into a failure; CI sets it. JRuby
  skips them in any case, its Nokogiri has no HTML5 parser.
- `spec/support/markdown_it/discourse.json` records what the setup is
  taken from: the Discourse commit, the markdown-it and linkify-it
  versions in its `pnpm-lock.yaml`, the site setting defaults and a hash
  of each Discourse file `cook.mjs` copies options from. `node
  spec/support/markdown_it/sync.mjs` updates it (and `package.json`) from
  Discourse main; when a hash changed, read the compare link it prints and
  update `cook.mjs` if needed. `--check` only reports, the weekly
  `discourse-sync.yml` workflow runs it. Dependabot does not watch this
  package on purpose: the version has to follow Discourse.
- Plain markdown-it is not all of Discourse: BBCode, mentions, emoji,
  `upload://`, image options and the sanitizer are missing, and
  Discourse's own typographer replacements are not copied (GPL), so
  markdown-it's `replacements` rule is off.

## Mutation Testing

The full playbook — wrapper usage, killing/simplifying/ignoring alive
mutations, the ignore-comment requirement, project-specific traps, and
the commit flow — lives in `.claude/skills/mutant/SKILL.md` and loads
automatically when mutation work comes up.

## Performance Notes

**Run every benchmark through `bin/bench-env`** (e.g. `bin/bench-env
bundle exec ruby --yjit bench/bench.rb --isolated`). It pins the process
to the fastest cores and reports power and governor state. Results from
a laptop on battery, or from an efficiency core, don't compare with
the numbers in `docs/src/content/docs/concepts/benchmarks.md`.

**MarkdownEscaper** is a hot path. Benchmark before/after any change to
`lib/markbridge/renderers/discourse/markdown_escaper.rb` with the
isolated escape reports (`bundle exec ruby --yjit bench/bench.rb
--single escape_plain` and `--single escape_mixed`). Tests over
refactors when behavior is equivalent.

**Scanner** (performance-critical):
- Byte offsets everywhere: `byteindex`/`byteslice`/`getbyte`, never
  character indices (`str[pos]` is O(pos) on multibyte input — CRuby has
  no character-index cache) and never per-char probe strings
- Every offset must sit on a character boundary (held structurally:
  jumps land on ASCII matches, advances step over ASCII bytes)
- Classify bytes with integer range checks, not regexes; `byteindex`
  returns 0 for a match at the start — nil-check, don't truthiness-check
- Bounded backtracking: save position, restore on failure
- Measure with `bench/corpus_bench.rb` (isolating variants) and
  `bench/alloc_profile.rb` (per-line allocation ranking) before and
  after changes; always compare the ascii and multi corpora

**Parsing/rendering setup**:
- `HandlerRegistry.shared_default` / `TagLibrary.shared_default` are
  built once per process (deep-frozen); the no-customization paths use
  them. Never mutate them — build a fresh `.default` (or `dup`) for
  customization

**AST**:
- Text nodes auto-merge (reduces tree size)
- `AST::Text` shares frozen input strings (copy-on-write; `merge` dups
  before its first append) — pass frozen strings on hot paths

**Renderer**:
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
- **docs/src/content/docs/concepts/architecture.md**: System architecture and design patterns
- **docs/src/content/docs/format-guides/**: BBCode, HTML, and TextFormatter parser guides
- **docs/src/content/docs/concepts/renderers.md**: Discourse renderer guide
- **docs/src/content/docs/customization/extending.md**: How to add custom tags and handlers
- **docs/src/content/docs/concepts/performance.md**: Performance optimization guide
- **spec/docs/**: Checks for runnable documentation examples and AST coverage
- **spec/**: Executable documentation (tests show expected behavior)

---

**Maintenance**: This file should be updated when core architecture changes. Details that change frequently (file counts, specific line numbers, step-by-step tutorials) are intentionally excluded. Point to the docs site and spec/ for those.

**Last Updated**: 2025-11-26
**Version**: 0.1.0
