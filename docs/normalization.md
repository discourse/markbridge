# AST Normalization

Real markup nests elements in ways the target format can't express: a link
inside a link, an image inside a link, a block element inside any inline
container (a link label, but equally bold or a heading). Left alone, these
render as broken Markdown — the inner link wins and the outer degrades to
text, a linked image comes out as `[![alt](src)](url)`, a block's blank
lines break out of the emphasis or `[…](url)` wrapping it.

`Markbridge::Normalizer` walks the AST once, between the parse-time `yield`
hook and rendering, and rewrites it so the renderer is only ever handed
legal markup. It runs **by default**. The renderer's tags stay simple
string emitters — the nesting knowledge lives here, one level up, in a
single place every consumer shares.

## Where it runs

```
parse → yield(ast) → normalize → render
```

Because it runs after the `yield` hook, AST mutations you make in that
block get normalized too. It runs for every source format and for
`Markbridge.render`, since normalization is about the *target* format, not
the source.

## Two rule layers

1. **CommonMark layer** — objective legality from the spec. Break these and
   the emitted Markdown does not parse back as the tree intended:
   - no link inside a link, at any depth (§6.3)
   - an *inline container* holds inline content only, so any block element
     inside one is hoisted out. This is **not** link-specific: emphasis
     (`Bold`, `Italic`, …) and headings are inline containers too, so a poll
     inside bold or a list inside a heading is fixed just like a block inside
     a link. The authoritative lists are `Normalizer::Layers::INLINE_CONTAINERS`
     and `BLOCK_NODES` (which covers `List`, `Table`, `Quote`, `Details`,
     `HorizontalRule`, `Align`, and the Discourse `Poll`/`Event` stubs).
   - a code span inside an inline container is legal only while it stays
     inline (single line); a fenced/multi-line block is hoisted out
2. **Discourse layer** — renderer policy on top:
   - image-likes (`Image`, `Upload`, `Attachment`) inside a **link** are
     hoisted out. Unlike the block rules above, this is policy rather than
     legality: `[![alt](src)](url)` is valid CommonMark, but Discourse wants
     the image beside the link, not wrapping it. (Image-likes are inline, so
     they are legal inside emphasis and stay put there — only the link case
     is a violation.)
   - a `Mention` inside a link is kept — it renders as literal `@name`,
     which is what Discourse cooks inside a link anyway

`Markbridge::Normalizer.common_mark` gives you just the first layer;
`Markbridge::Normalizer.discourse` gives you both.

## Strategies

Each violation resolves to one strategy:

| Strategy | Effect |
|----------|--------|
| `:keep` | Explicitly allow it (documents a decision, silences the report). |
| `:hoist_after` | Move the node out to a sibling after the *outermost* offending ancestor, preserving document order. An image nested in a bold that is itself inside a link lands after the **whole link** — clearing both, since the bold sits inside the link — not stranded after the bold inside the link. (The walker only ever moves a node *out* to a sibling; it never inserts one into a wrapper it wasn't already in.) |
| `:unwrap` | Dissolve the element, splicing its children into its place. The built-in case is the inner link of a nested pair: `[[text](inner)](outer)` becomes `[text](outer)` — the inner link's wrapper and its href are dropped, its text kept under the outer link. |
| `:textify` | Replace the subtree with its plain-text projection (`@name` for a mention, concatenated text otherwise). |
| `:drop` | Remove it entirely. |
| callable | `->(boundary, node) { … }` returning a strategy symbol, an `Array<AST::Node>` to splice, or `nil` to drop — the escape hatch for anything the built-ins don't cover. |

A formatting wrapper (bold, italic, color, …) left childless by a hoist or
drop is pruned, so no `****` husks remain. An empty **link** is the
exception — it is kept, because it renders as a meaningful bare URL.

## Diagnostics

Every transformation is reported through the same channel as
`unknown_tags`:

```ruby
conversion = Markbridge.convert(input, format: :bbcode)
conversion.diagnostics[:normalization]
# => [{ parent: "Url", child: "Image", strategy: :hoist_after, count: 3 }]
```

For a migration this feeds per-post warnings and tells you which sources
produce degenerate trees — the data that decides where converter work goes
next. The key is absent when nothing changed.

## Opting out and customizing

`normalize:` accepts `true` (default, the shared Discourse normalizer),
`false` (skip), or a `Normalizer` instance:

```ruby
# Skip normalization entirely
Markbridge.convert(input, format: :bbcode, normalize: false)

# Layer your own rules on top of the defaults
normalizer = Markbridge::Normalizer.discourse
normalizer.rule(parent: Markbridge::AST::Url, child: Markbridge::AST::Mention, strategy: :textify)
Markbridge.convert(input, format: :bbcode, normalize: normalizer)
```

A rule for a `(parent, child)` pair that already has one replaces it, so
your `#rule` calls override the built-in layers. Matching is by exact class
(`instance_of?`), so a rule for `AST::Url` never accidentally catches a
subclass.

The no-customization path uses `Markbridge::Normalizer.shared_discourse`,
a memoized, deep-frozen instance built once per process — do not mutate it
(call `.discourse` for a fresh, customizable one).

## Validation mode

The same rules, without mutation:

```ruby
Markbridge::Normalizer.common_mark.violations(ast)
# => [{ parent: "Url", child: "Image", strategy: :hoist_after }]
```

Two uses: assert in your own test suite that the trees your parsers and tag
fixtures build satisfy the CommonMark layer (the rules double as an
executable spec of what the renderer may be handed), or run it as a lint
over a corpus without changing any output. After a `normalize`, the
CommonMark layer reports nothing — normalization reaches a fixpoint in a
single pass.

## Adding a target format

`Markbridge::Normalizer::Layers` holds the rule tables — `common_mark`
(objective legality) and `discourse` (policy on top). The engine (`RuleSet`,
`Walker`) is format-agnostic, so a second target would add a `Layers` method
and a matching `Normalizer.<target>` accessor; nothing else changes.
