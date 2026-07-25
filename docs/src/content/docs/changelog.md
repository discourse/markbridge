---
title: Changelog
description: Release notes for Markbridge, sourced from GitHub Releases.
---

### v0.3.1 — 2026-07-20

#### Features
* Add an AST normalization pass for target-format nesting rules ([#67](https://github.com/discourse/markbridge/pull/67))

**Full Changelog**: https://github.com/discourse/markbridge/compare/v0.3.0...v0.3.1

---

### v0.3.0 — 2026-07-09

:::caution
This release contains breaking changes — see [UPGRADING.md](https://github.com/discourse/markbridge/blob/v0.3.0/UPGRADING.md) before updating.
:::

#### Features
* Expose the bare-link judgment as AST::Url#bare? ([#62](https://github.com/discourse/markbridge/pull/62))
* Let tag overrides fall back to the stock rendering ([#62](https://github.com/discourse/markbridge/pull/62))
* Keep bare and relative URLs intact in UrlTag ([#62](https://github.com/discourse/markbridge/pull/62))

#### Bug Fixes
* Model quote attributions with honest names and types ([#62](https://github.com/discourse/markbridge/pull/62))

#### Performance
BBCode and MediaWiki now convert roughly twice as fast, HTML about 1.5×, with allocations down 3–9.5× depending on the format. Multibyte text no longer carries a penalty — scanning non-ASCII BBCode was up to 5× slower than ASCII and is now at parity.

* Trim TextFormatter per-parse and per-element overhead ([#61](https://github.com/discourse/markbridge/pull/61))
* Cut the HTML tree walk's per-node overhead ([#61](https://github.com/discourse/markbridge/pull/61))
* Build the MediaWiki inline tag registry only once ([#60](https://github.com/discourse/markbridge/pull/60))
* Convert the MediaWiki inline parser to byte-offset jump scanning ([#60](https://github.com/discourse/markbridge/pull/60))
* Skip the line split for single-line text in MarkdownEscaper ([#59](https://github.com/discourse/markbridge/pull/59))
* Turn RenderContext into a linked parent chain ([#59](https://github.com/discourse/markbridge/pull/59))
* Cut small allocations in the parse and render hot paths ([#58](https://github.com/discourse/markbridge/pull/58))
* Convert the BBCode scanner to byte offsets ([#58](https://github.com/discourse/markbridge/pull/58))
* Build the default handler registry and tag library only once ([#58](https://github.com/discourse/markbridge/pull/58))

**Full Changelog**: https://github.com/discourse/markbridge/compare/v0.2.1...v0.3.0

---

### v0.2.1 — 2026-07-06

#### Removed
* Removed the `Markbridge::Processors::DiscourseMarkdown` module — the scanner and the mention/poll/event/upload detectors. This code is moving into the Discourse migrations tooling. ([#56](https://github.com/discourse/markbridge/pull/56))

**Full Changelog**: https://github.com/discourse/markbridge/compare/v0.2.0...v0.2.1

---

### v0.2.0 — 2026-06-11

#### Breaking Changes

The migration API was redesigned around structured result types ([#30](https://github.com/discourse/markbridge/pull/30)). [UPGRADING.md](https://github.com/discourse/markbridge/blob/v0.2.0/UPGRADING.md) has before/after examples for every change.

* `parse_*` methods now return a `Parse` and `*_to_markdown` / `convert` return a `Conversion` instead of raw `String`s — use `Conversion#markdown` (or `#to_s`) for the output ([#30](https://github.com/discourse/markbridge/pull/30))
* Global configuration is gone: `Markbridge::Configuration`, `.configure`, `.reset_defaults!`, and all `default_*` accessors were removed — build a reusable renderer with `Markbridge.discourse_renderer(...)` and pass it via `renderer:` ([#30](https://github.com/discourse/markbridge/pull/30))
* `tags:`, `tag_library:`, `escaper:`, and `escape_hard_line_breaks:` were removed from the per-call signatures; `*_to_markdown` / `convert` accept only `handlers:`, `renderer:`, and `raise_on_error:` ([#30](https://github.com/discourse/markbridge/pull/30))
* Proc/lambda handlers are no longer supported — handlers must be objects responding to `#process(...)` ([#30](https://github.com/discourse/markbridge/pull/30))
* MediaWiki parser kwarg renamed: `inline_tag_registry:` → `handlers:` ([#30](https://github.com/discourse/markbridge/pull/30))
* TextFormatter handlers must accept a `processor:` keyword ([#30](https://github.com/discourse/markbridge/pull/30))

#### Features
* `Markbridge.discourse_renderer(...)` factory builds reusable `Renderer` instances — accepts `tags:`, `tag_library:`, `unregister:`, `escaper:`, `escape:`, `escape_hard_line_breaks:`, `allow:`, `postprocessor:`, `strip_trailing_invisibles:` ([#30](https://github.com/discourse/markbridge/pull/30))
* `Markbridge.convert(format:)` dispatcher and polymorphic `Markbridge.render(Parse | AST::Node)` ([#30](https://github.com/discourse/markbridge/pull/30))
* AST mutation between parse and render: block form on every `*_to_markdown` / `convert`, plus `AST::Element#each_descendant`, `#descendants(klass = nil)`, and `#replace_child(old, new)` ([#30](https://github.com/discourse/markbridge/pull/30))
* `raise_on_error: false` collects render errors on `Conversion#errors` for per-row failure isolation in batch migrations ([#30](https://github.com/discourse/markbridge/pull/30))
* Selective Markdown escaping via `MarkdownEscaper#allow:` (`:bullet_list`, `:ordered_list`, `:atx_heading`, `:block_quote`, alias `:lists`), and `IdentityEscaper` / `discourse_renderer(escape: false)` for already-trusted Markdown ([#30](https://github.com/discourse/markbridge/pull/30))
* Handler registries gain `#overlay(name) { |previous| ... }` for wrapping default handlers (BBCode, HTML, TextFormatter) ([#30](https://github.com/discourse/markbridge/pull/30))
* `TagLibrary#unregister` — unregistered AST classes auto-pass-through to their rendered children ([#30](https://github.com/discourse/markbridge/pull/30))
* HTML and TextFormatter parsers accept pre-parsed Nokogiri input (`DocumentFragment`, `Document`, `Element`) in addition to Strings ([#30](https://github.com/discourse/markbridge/pull/30))
* `AST::Details` + `DetailsTag` for Discourse `[details=…]…[/details]` collapsible sections ([#30](https://github.com/discourse/markbridge/pull/30))
* Optional strip_trailing_invisibles config flag ([#39](https://github.com/discourse/markbridge/pull/39))
* Collapse whitespace in HTML per spec ([#36](https://github.com/discourse/markbridge/pull/36))
* Map inline span styles to AST formatting nodes ([#34](https://github.com/discourse/markbridge/pull/34))

#### Bug Fixes
* Make RenderContext parent-queries answer is_a? semantics ([#42](https://github.com/discourse/markbridge/pull/42))
* Move ] label-escape into MarkdownEscaper so image-in-link works ([#41](https://github.com/discourse/markbridge/pull/41))
* Escape ] in link labels to prevent early link termination ([#40](https://github.com/discourse/markbridge/pull/40))
* Insert blank line between raw text and following block elements ([#37](https://github.com/discourse/markbridge/pull/37))
* Skip [u] wrapper inside [url] and [email] ([#36](https://github.com/discourse/markbridge/pull/36))
* Skip [u] wrapper when underline content is whitespace-only ([#35](https://github.com/discourse/markbridge/pull/35))
* Treat Unicode whitespace as whitespace in RenderingInterface#wrap_inline ([#33](https://github.com/discourse/markbridge/pull/33))

**Full Changelog**: https://github.com/discourse/markbridge/compare/v0.1.3...v0.2.0

---

### v0.1.3 — 2026-05-07

#### Bug Fixes
* Treat \r as part of CRLF terminator in MarkdownEscaper ([#32](https://github.com/discourse/markbridge/pull/32))

**Full Changelog**: https://github.com/discourse/markbridge/compare/v0.1.2...v0.1.3

---

### v0.1.2 — 2026-05-05

#### Features
* Make BBCode HandlerRegistry and Discourse TagLibrary enumerable ([#28](https://github.com/discourse/markbridge/pull/28))

#### Bug Fixes
* Name receiver class in AST::Element#<< type error ([#28](https://github.com/discourse/markbridge/pull/28))
* Copy text into a fresh buffer in AST::Text ([#28](https://github.com/discourse/markbridge/pull/28))
* Render Markdown as HTML inside the table fallback (html_mode) ([#26](https://github.com/discourse/markbridge/pull/26))

**Full Changelog**: https://github.com/discourse/markbridge/compare/v0.1.1...v0.1.2

---

### v0.1.1 — 2026-04-24

#### Features
* Add Markdown table support with HTML fallback ([#13](https://github.com/discourse/markbridge/pull/13))

#### Bug Fixes
* Drop raw-text and metadata HTML elements entirely ([#16](https://github.com/discourse/markbridge/pull/16))
* Emit trailing blank line after quotes ([#21](https://github.com/discourse/markbridge/pull/21))
* Emit trailing blank line after more block-level tags ([#22](https://github.com/discourse/markbridge/pull/22))

**Full Changelog**: https://github.com/discourse/markbridge/compare/v0.1.0...v0.1.1

---

### v0.1.0 — 2026-03-31

**Full Changelog**: https://github.com/discourse/markbridge/commits/v0.1.0
