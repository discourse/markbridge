# Migration API plan

Markbridge's primary use case is forum migrations to Discourse. The current
public API serves the *parse → AST → render* path well; what's awkward is the
layer above it, where importer code resolves source IDs to Discourse IDs,
emits placeholders for the importer to swap in, and tracks side data per post.

This document captures what the next API iteration should make easy. It lives
on the `docs` branch as a parking place for context — actual API work happens
on a fresh branch off `main`. No backwards-compatibility constraints.

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

### 1. Result object from convenience methods

Make `Markbridge.<format>_to_markdown` return a richer object.

```ruby
result = Markbridge.html_to_markdown(input, handlers:, tag_library:)
result.markdown                # the rendered string (`result.to_s` too)
result.unknown_tags            # { "marquee" => 3, "blink" => 1 }
result.emitted(:uploads)       # whatever Tags emitted under :uploads
result.emitted(:mentions)
```

### 2. Tag side-data emission

Extend the rendering interface so `Tag#render` can attach metadata without
threading mutable collaborators through the constructor.

```ruby
class UploadTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    interface.emit(:uploads, id: element.upload_id, path: element.path)
    "[upload|#{element.upload_id}]"
  end
end
```

The renderer collects emissions; the result object surfaces them by key.

### 3. Overlay registration / handler chaining

`HandlerRegistry#register` returns the previously-registered handler, or a
new `overlay` method exposes the delegate.

```ruby
registry.overlay("a") do |delegate|
  Anchor.new(default: delegate, prefix:, root:, ...)
end
```

Or a middleware-style API where `process` receives the delegate as an arg.

### 4. Built-in placeholder DSL (optional)

Small DSL so simple placeholder triads don't need three classes.

```ruby
Markbridge::Placeholder.define(:upload) do
  attribute :upload_id
  attribute :path
  render { |el| "[upload|#{el.upload_id}]" }
  emit(:uploads) { |el| { id: el.upload_id, path: el.path } }
end
```

The handler still has to construct it (resolution is project-specific), but
the AST + Tag + emit boilerplate is gone.

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

## Open questions

- Should the existing `*_to_markdown` methods change shape (breaking) or
  live alongside `*_to_result` companions? Likely change shape — no
  backwards-compat constraint.
- Side-data emission keys: open-ended symbols, or a fixed enum? Open-ended
  is simpler; fixed enum gives more type-safety.
- Default-handler chaining via `super` in the handler class, or a
  block-passed `delegate` parameter?
- Should the result object expose timing / counts (handlers invoked,
  AST node count) for benchmarking?

## Working branch

Implementation lands on `migration-api` (off `main`). Once the API
stabilizes, the `docs` branch picks up the new shape and writes the
`migrating/` guides on top.
