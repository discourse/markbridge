# Migration API plan

Markbridge's primary use case is forum migrations to Discourse. The current
public API serves the *parse → AST → render* path well; what's awkward is the
layer above it, where importer code resolves source IDs to Discourse IDs,
emits placeholders for the importer to swap in, and tracks side data per post.

This document captures what the next API iteration should make easy. It lives
on the `docs` branch as a parking place for context — actual API work happens
on a fresh branch off `main`. No backwards-compatibility constraints.

**Status (2026-05-06):** PR #30 (`claude/refine-local-plan-dMDie`) implements
§1–§3 below. §4 is rejected. Sections marked **Implemented** describe what
shipped; the original sketches are preserved for context.

## The user journey

Source markup (BBCode / HTML / MediaWiki / TextFormatter XML) → AST →
Discourse-flavored Markdown, with several kinds of inline content rewritten
to *placeholders* that the Discourse importer fills in later:

- internal and external links (topic-id rewrites, mailto)
- images
- attachments / uploads
- events
- polls
- mentions
- quotes

For each placeholder, the migration also needs to capture **side data** that
travels alongside the rendered Markdown — the upload IDs the post references,
the mention IDs to look up later, the unresolved-name list, and so on.

The migration also needs to know which source tags weren't recognized so it
can decide whether to drop them, log them, or fail.

## What the current API supports

- Custom handlers per parser (`HandlerRegistry.register`).
- Custom Tag classes per AST node (`TagLibrary.register` / `auto_register!`).
- `parser.unknown_tags` on a parser instance.
- The full Parse → AST → Render pipeline is composable from the outside.

## What's awkward (concrete observations from a real importer)

A real importer (~300 lines of Markbridge-glue code, separate project) repeats
these patterns:

1. **Default-handler fallback**: every custom handler keeps a private instance
   of the gem's default and delegates when its own logic doesn't apply. The
   gem doesn't expose the previously-registered handler.

   ```ruby
   class Anchor
     def initialize(default: Markbridge::Parsers::HTML::Handlers::UrlHandler.new)
       @default = default
     end

     def process(element:, parent:)
       internal?(element) ? handle_internal(element, parent) : @default.process(element:, parent:)
     end
   end
   ```

2. **Side-data trackers**: handlers and tags need a place to record metadata
   while they run (upload IDs collected, mentions resolved, links recorded).
   Today this is solved by injecting mutable arrays into Tag constructors and
   exfiltrating them after the run.

   ```ruby
   tracker = []
   tag_library.register(MentionAst, MentionTag.new(tracker))
   Markbridge.html_to_markdown(...)
   post.placeholders[:mentions] = tracker
   ```

   The Tag API has no concept of "this rendering produced metadata".
   `Tag#render` returns only a string.

3. **The placeholder triad** is verbose: every placeholder concept ends up
   needing a custom AST class, a custom handler that resolves IDs and
   constructs the AST node, and a custom Tag that renders the placeholder
   string while pushing side data. Three small files per placeholder.

4. **No high-level access to `unknown_tags`**: the convenience method
   `Markbridge.html_to_markdown(input)` returns only a `String`. To get
   unknown tags you drop to the parser-and-renderer dance.

## Proposed API additions

In rough priority order. None of these are committed yet — they're sketches.

### 1. Result object from convenience methods — Implemented (PR #30)

`Markbridge.<format>_to_markdown` returns a `Conversion`; `parse_<format>`
returns a `Parse`. Both are immutable `Data.define` value objects.

```ruby
result = Markbridge.html_to_markdown(input, handlers:, renderer:)
result.markdown        # rendered string (also via to_s, so puts/interpolation work)
result.ast             # AST::Document
result.format          # :html
result.unknown_tags    # { "marquee" => 3, "blink" => 1 }
result.diagnostics     # format-specific (BBCode supplies :auto_closed_tags_count, etc.)
result.emissions       # { uploads: [...], mentions: [...] }
result.emitted(:uploads)  # convenience: returns [] for missing keys
result.errors          # [] unless raise_on_error: false swallowed something
```

Note: the sketch's `tag_library:` parameter became `renderer:` — see the
"Out-of-band changes" section below for why.

### 2. Tag side-data emission — Implemented (PR #30)

The rendering interface gained `emit(key, payload)`. Tags call it freely
during render; the renderer collects emissions and resets between
top-level calls. `Conversion#emissions` (and `#emitted(key)`) surface
them.

```ruby
class UploadTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    interface.emit(:uploads, id: element.upload_id, path: element.path)
    "[upload|#{element.upload_id}]"
  end
end
```

Emission keys are open-ended symbols; payloads are arbitrary. Zero
overhead on the no-emit path so the same `Renderer` instance is safe to
reuse across thousands of posts.

### 3. Overlay registration / handler chaining — Implemented (PR #30)

`HandlerRegistry#overlay` (BBCode, HTML, TextFormatter) replaces the
handler bound to one or more tag names by yielding the previously-bound
handler (which may be `nil`) and registering whatever the block returns.

```ruby
registry.overlay(%w[url link iurl]) do |default|
  LinkifyingUrlHandler.new(default:)
end
```

Chosen over the middleware-style `process(..., delegate:)` shape because
overlay keeps handlers as plain objects — the delegate is captured at
registration time, not pushed through every call.

### 4. Built-in placeholder DSL — considered and rejected

Earlier drafts proposed a DSL to collapse the AST + Tag + emit boilerplate
into a single declarative block:

```ruby
Markbridge::Placeholder.define(:upload) do
  attribute :upload_id
  attribute :path
  render { |el| "[upload|#{el.upload_id}]" }
  emit(:uploads) { |el| { id: el.upload_id, path: el.path } }
end
```

Rejected once §1–§3 landed, for these reasons:

- **Bounded win**: the triad is already small (a few lines of AST, a few
  lines of Tag) once `interface.emit` and `overlay` exist. Saves maybe
  ~15 lines per placeholder over ~7 placeholders.
- **Discoverability cost**: synthesized classes don't show up in `grep`.
  Stack traces reference `Markbridge::Placeholder::Upload` with no source
  file to jump to.
- **Edge cases re-introduce the classes**: html_mode output (per the
  contract in `CLAUDE.md`), multiple emits per placeholder, custom AST
  equality / pattern-matching — each of these wants an escape hatch back
  to a hand-written class, which dilutes the DSL's payoff.
- **The handler stays hand-written either way**: resolution logic is
  project-specific (DB lookup, ID map, slug rewrite). The DSL would only
  ever cover the two mechanical sides, which aren't the painful sides.

## Docs reorganization that follows

Once the API additions land, restructure `docs/src/content/docs/guides/`:

```
guides/
├── migrating/
│   ├── overview.md            mental model: parse-resolve / render-emit /
│   │                          collect-side-data
│   ├── placeholders.md        the recurring triad, end-to-end
│   ├── links.md               internal vs external, topic-id rewrites
│   ├── images-and-attachments.md
│   ├── mentions.md
│   ├── quotes-and-events.md
│   ├── unknown-tags.md
│   └── full-walkthrough.md    a runnable mini-importer
├── extending.md               kept; for tags built from scratch
├── bbcode.md                  per-format guide (already exists)
├── html.md
├── mediawiki.md
└── textformatter.md
```

Each `migrating/*` recipe is runnable end-to-end. The new pages drive the
API design — anywhere the recipe gets verbose is a hint that the API needs
work.

## Out-of-band changes in PR #30

PR #30 also made changes that weren't called out in the original plan but
fall out of the same redesign:

- **Removed `Markbridge::Configuration`**. The global singleton + per-process
  default registries are gone. Customization is now explicit per call
  (`handlers:`, `renderer:`), which makes parallel/forked workers safe.
- **`Markbridge.discourse_renderer(...)` factory**. Builds a reusable
  `Renderer` from `tags:`, `escape_hard_line_breaks:`, `escaper:`,
  `html_escaper:`, `postprocessor:`. Replaces per-call `tag_library:`,
  `escaper:`, `escape_hard_line_breaks:` parameters — build once, reuse
  across thousands of posts.
- **`TagLibrary#unregister`** + **auto-passthrough** for unregistered AST
  classes — eliminates boilerplate "passthrough" Tags.
- **`Postprocessor`** that collapses excess newlines, strips
  whitespace-only lines, and trims document edges.
- **`raise_on_error: false`** on `*_to_markdown`/`convert` — swallows
  render-time errors and surfaces them via `Conversion#errors` so a
  batch migration can isolate per-row failures.
- **MediaWiki API parity**: `inline_tag_registry:` parameter renamed to
  `handlers:`.
- **TextFormatter handler signature**: handlers now accept `processor:`
  for consistency with the other parsers.

## Open questions — resolutions

- *Change shape vs. add `*_to_result` companions?* → Changed shape.
  Breaking, no compat shim.
- *Emission keys: open-ended or fixed enum?* → Open-ended symbols.
- *Chaining via `super` or block-passed delegate?* → Block-passed
  delegate (`overlay`).
- *Timing/counts on the result object?* → Not exposed. `Conversion`
  carries `ast`, `unknown_tags`, `diagnostics`, `emissions`, `errors`
  only. Benchmarking lives outside the result.

## Working branch

Implementation lives on `claude/refine-local-plan-dMDie` (PR #30). Once
that merges to `main`, the `docs` branch will pick up the new API shape
and the `migrating/*` guides described above can be written against it.
