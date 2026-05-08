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

## §5. Resolution architecture (post-implementation refinement)

A design pass after PR #30 was drafted concluded that placeholder
*resolution* — the position-to-upload-id, name-to-user-id, slug-to-
topic-id translations a migration needs — should happen at **parse
time inside custom handlers**, not at render time inside Tags. That
flips two assumptions in §1–§3 and obsoletes §2 entirely.

### The shape

A converter framework (separate library, sits *above* Markbridge) owns
the resolution layer:

- **Markbridge** provides parser/handler/AST/renderer primitives.
- **Converter framework** provides resolution-aware base handlers
  (`BaseAttachmentHandler`, `BaseMentionHandler`, …), the placeholder
  AST classes they construct, and trivial render Tags. Owns the
  `[upload|<id>]` placeholder convention.
- **Per-format converters** (phpBB, vBulletin, SMF, IPB, XenForo)
  subclass the base handlers via a template-method pattern, overriding
  only source-ref extraction. Same AST class, same Tag, three converters
  share the resolution logic.
- **Importer** is the downstream layer that consumes converted output
  and substitutes `[upload|<id>]` for the real `upload://...` reference
  once the file is ingested.

### Why parse-time resolution

The resolution isn't a pure lookup — it's a *write*. The handler stores
the source attachment in Discourse's upload store (idempotent on source
hash), receives an `upload_id`, and pins it on the AST node. The
storing side effect wants to happen once per source attachment, which
parse-time resolution gives for free. Render-time resolution would
re-store on every render or require an in-Tag cache.

Consequences:

1. **AST nodes carry resolved data.** `AttachmentPlaceholder(upload_id:)`
   is enough; no `position`/`filename` needed beyond what the handler
   used to do its work.
2. **Render Tags are trivial.** `def render(element, _) =
   "[upload|#{element.upload_id}]"`. No state, no per-post wiring.
   The renderer can be a singleton.
3. **Parse failures surface early.** Missing position, DB write error,
   etc. bubble up at parse time, attributable to the source post.
4. **AST loses the "renderer-agnostic" property.** It's resolved to
   Discourse-specific identifiers. Acceptable trade because the
   converter framework is Discourse-only by definition.
5. **Per-post wiring shifts to handlers**, not renderers. Same total
   work, different layer.

### `interface.emit` becomes unnecessary

`interface.emit` and `Conversion#emissions` (§2) were designed for
render-time side-data tracking. With resolution moved to parse time:

- The data the importer needs is already on the AST (handler-resolved).
- Walking the AST or recording side effects in the handler covers
  every "what did this post reference?" question.
- No render-time-only context needs to flow back to the caller.

§2 is therefore obsoleted. PR #30 should remove the emit API before
merge — see "PR #30 change list" below.

### Per-format handler reuse

Template-method shape lives in the converter framework:

```ruby
class BaseAttachmentHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
  def initialize(attachment_store:)
    @attachment_store = attachment_store
    @element_class = AttachmentPlaceholder
    @collector = Markbridge::Parsers::BBCode::RawContentCollector.new
  end
  attr_reader :element_class

  def on_open(token:, context:, registry:, tokens: nil)
    source_ref = extract_source_ref(token, tokens)
    return context.add_child(fallback_for(token)) unless source_ref

    upload_id = @attachment_store.store_or_lookup(source_ref)
    context.add_child(AttachmentPlaceholder.new(upload_id:))
  end

  def extract_source_ref(token, tokens) = raise NotImplementedError
  def fallback_for(token) = Markbridge::AST::Text.new(token.source)
end

# phpBB: position into per-post attachments table
class PhpBB::AttachmentHandler < BaseAttachmentHandler
  def extract_source_ref(token, tokens)
    SourceRef.new(post_id: ..., position: Integer(token.attrs[:option]),
                  filename: @collector.collect(token.tag, tokens).content)
  end
end

# vBulletin: absolute attach_id
class VBulletin::AttachmentHandler < BaseAttachmentHandler
  def extract_source_ref(token, tokens)
    SourceRef.new(attach_id: Integer(token.attrs[:option]))
  end
end
```

The same pattern applies to mentions, polls, events, links. Markbridge
contributes the parser primitives (`BaseHandler`, `RawContentCollector`,
AST primitives like `Element`/`Node`/`Text`); the converter framework
contributes the resolution-aware base classes and the placeholder AST
classes.

### Idempotency and failure-mode invariants

The converter framework's base handlers have a small implicit contract:

- `attachment_store.store_or_lookup(source_ref)` is **idempotent** on a
  source-side identifier (most often a content hash). Two posts that
  reference the same source attachment must produce the same
  `upload_id`. A re-run of the converter must not duplicate uploads.
- Within a single converter run, the store should **memoize** so common
  attachments (avatars, signatures) aren't fetched repeatedly.
- The handler must define a **fallback** for resolution failure — most
  natural is an `AST::Text` with the raw source token, so the
  unresolved markup survives in the rendered output for human review.

### PR #30 change list (gem branch)

Concrete edits to make in `claude/refine-local-plan-dMDie` before
merge to undo §2:

1. `lib/markbridge/renderers/discourse/rendering_interface.rb` — remove
   the `#emit` method.
2. `lib/markbridge/renderers/discourse/renderer.rb` — remove
   `@emission_buffer`, `#emissions`, `#record_emission`,
   `#with_provisional_emissions`, `#snapshot_emissions`,
   `#rollback_emissions`, and the buffer reset in `#render`.
3. `lib/markbridge/conversion.rb` — drop the `emissions` field from
   `Data.define` and the `#emitted(key)` accessor.
4. `lib/markbridge.rb` — remove `emissions: renderer.emissions` (or
   equivalent) from `build_conversion` and any sibling Conversion
   constructions.
5. `examples/forum_migration.rb` — drop the `interface.emit(:link, ...)`
   call from `PlaceholderUrlTag`. Either resolve in a custom handler
   or drop the side-data tracking entirely (the example can still
   demonstrate the renderer factory, custom escaper, etc.).
6. `UPGRADING.md` — remove the "Tag side-data: use `interface.emit`"
   section. Replace with a brief note that resolution lives in
   handler subclasses (per the converter-framework architecture).
7. Specs — drop emission-related tests across:
   `spec/unit/markbridge/conversion_spec.rb`,
   `spec/unit/markbridge/renderers/discourse/renderer_spec.rb`,
   `spec/unit/markbridge/renderers/discourse/rendering_interface_spec.rb`.
   Verify nothing else references emissions.
8. Verify `bundle exec rake` and `bin/mutant` are green after.

### Docs branch follow-up

Once §5 is reflected in PR #30, the docs need a pass to match:

- `migrating/placeholders.md` — rewrite the worked example around
  handler-side resolution. AST node carries `upload_id`; Tag is
  trivial; remove the `interface.emit` references; remove the
  per-post renderer construction (handler holds per-post state
  instead).
- `migrating/overview.md` — drop the `interface.emit` side-channel
  callout from the four-stage description and the diagram.
- `migrating/full-walkthrough.md` — re-narrate `examples/forum_migration.rb`
  after the §2 removal lands.
- `placeholders.excalidraw` and its rendered SVGs — drop the
  emissions arrow from the triad diagram. The triad becomes
  source → handler → AST → Tag → placeholder string. No side channel.
- `customization/extending.md` — remove the `emit` row from the
  rendering-interface table.
- `concepts/renderers.md` — same.
- `reference/upgrading.md` — sync with PR #30's `UPGRADING.md`
  changes.

These are mechanical removals; happy to do them as a follow-up
commit on the `docs` branch once PR #30 lands the §2 removal.
