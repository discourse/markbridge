---
title: Performance
description: Where Markbridge is tuned and how to measure it on your own workload.
---

Markbridge is designed to run on large batches of forum content. The pipeline is O(n) in input size and avoids the quadratic traps common to regex-based approaches.

## Where time is spent

**Scanner (BBCode)** is the hottest path for large inputs. It uses:

- Index-based character access (`@input[@pos]`, not slice-based reads).
- Bounded backtracking — positions are saved and restored, never rewound blindly.
- Regex only for character classes.
- Minimal string allocations — buffers are reused across tokens.

**HTML / TextFormatter** delegate tokenization to Nokogiri (libxml2 on MRI and TruffleRuby; Xerces/NekoHTML on JRuby). The walker on top is a straight depth-first traversal.

**MediaWiki** is line-based — one pass through the lines, with a small inline parser for intra-line formatting.

**Renderer**:

- Single-pass depth-first walk.
- Parent lookups (`has_parent?`, `find_parent`) are O(1) via a hash cache on `RenderContext`.
- `Text` nodes auto-merge during AST construction, so the tree is smaller than the raw token stream.

## Bounded operations

A few hard caps prevent pathological input from hanging the parser:

| Limit | Value | Location |
|---|---|---|
| Max nesting depth | 100 | `ParserState` |
| Max auto-close depth | 5 | `ClosingStrategies::TagReconciler` |

Exceeding the max nesting depth raises `MaxDepthExceededError`. The auto-close depth fails quietly — the parser stops searching for a matching opener and continues. The same bound limits how far `Reordering` will peek ahead when reconciling mismatched closes.

## Ruby version and YJIT

Markbridge targets Ruby 3.3+ on CRuby, and also runs on the latest TruffleRuby and JRuby (their own JITs cover the hot paths). On CRuby, enabling YJIT gives a consistent speedup on the parsing and rendering hot paths:

```bash
ruby --yjit your_script.rb
```

Or in-process:

```ruby
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)
```

## Memory

Markbridge renders fully in memory — no streaming API. For a single post this is negligible; for a batch of millions, stream at the caller:

<!-- spec:before
require "csv"
csv_data = "id,body\n1,[b]hi[/b]\n"
CSV.define_singleton_method(:foreach) do |_path, **opts, &block|
  CSV.parse(csv_data, **opts, &block)
end
output_db = Class.new { def insert(*); end }.new
-->
```ruby
CSV.foreach("posts.csv", headers: true) do |row|
  markdown = Markbridge.bbcode_to_markdown(row["body"])
  output_db.insert(row["id"], markdown)
end
```

Don't accumulate ASTs or rendered output across iterations — let Ruby GC them as you go.

## Reusing the default registries

`HandlerRegistry.default` and `TagLibrary.default` are memoized on the `Markbridge` module. The first call builds them; subsequent calls reuse the cached instance. Calling `Markbridge.*_to_markdown` in a loop doesn't pay the registry construction cost per call.

If you pass a custom `handlers:` or `tag_library:`, build it once outside the loop and reuse it.

## Measuring on your workload

The numbers that matter are from your data. A minimal script:

<!-- spec:before
File.define_singleton_method(:readlines) { |_path, **| ["[b]hi[/b]", "[i]world[/i]"] }
-->
```ruby
require "benchmark"
require "markbridge/bbcode"

inputs = File.readlines("corpus.txt", chomp: true)

Benchmark.bm(20) do |x|
  x.report("bbcode_to_markdown") do
    inputs.each { |s| Markbridge.bbcode_to_markdown(s) }
  end
end
```

For profiling specific inputs, reach for `ruby-prof` or `stackprof` and focus on the scanner and the renderer — those are the only two places that touch every character or every node.

## When it's slow anyway

Almost always, one of:

1. **Custom handler doing real work.** A handler that parses attribute JSON, hits the filesystem, etc., dwarfs everything else. Profile the handler, not Markbridge.
2. **Input that blows past the depth limit.** Deeply nested inputs can still be expensive even below the cap. Consider a Strict closing strategy to fail faster on adversarial input.
3. **Rendering inside a tight outer loop.** If you're reusing the same tag library per call, make sure it's built outside the loop (see above).
