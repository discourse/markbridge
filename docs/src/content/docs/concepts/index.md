---
title: Concepts
description: How Markbridge works under the hood — the pipeline, the AST, parsers, renderers, and performance.
---

The deep dives, for when you want to understand or change how Markbridge works:

- **[Architecture](/concepts/architecture/)** — the parse → AST → render pipeline, and why it's shaped that way.
- **[The AST](/concepts/ast/)** — node types, invariants, and how the tree is built and walked.
- **[Parsers](/concepts/parsers/)** — how each of the four parsers works, and their trade-offs.
- **[Renderers](/concepts/renderers/)** — the Discourse renderer, Tags, and the rendering interface.
- **[Performance](/concepts/performance/)** — where the pipeline is tuned, and how to measure your own workload.
