---
title: Concepts
description: How Markbridge works — the pipeline, the AST, parsers, renderers, and performance.
---

Read these pages when you want to understand how Markbridge works, or before you change how it works:

- **[Architecture](/concepts/architecture/)** — the three steps of a conversion and why they are separate.
- **[The AST](/concepts/ast/)** — the node types, the rules of the tree, and how to build and walk it.
- **[Result objects](/concepts/result-objects/)** — what a conversion returns: `Conversion` and `Parse`.
- **[Parsers](/concepts/parsers/)** — how each of the four parsers works and where they differ.
- **[Renderers](/concepts/renderers/)** — the Discourse renderer, its tags, and what a tag can ask the renderer.
- **[AST normalization](/concepts/normalization/)** — the step that rewrites nesting Markdown cannot express.
- **[Performance](/concepts/performance/)** — what to reuse, the limits of the parsers, and how to measure your own input.
- **[Benchmark results](/concepts/benchmarks/)** — recorded measurements on CRuby, JRuby and TruffleRuby.
