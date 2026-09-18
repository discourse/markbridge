---
title: Performance
description: Reuse your configuration, process large inputs, and measure conversion speed.
---

Measure performance with representative input. Document size, nesting, custom handlers, and your Ruby engine all affect conversion time.

## Reuse your configuration

The default handler registries and tag library are shared and frozen. Use `.default` to build a fresh registry when you need to customize it.

Build a custom renderer once and reuse it across conversions:

<!-- spec:before
posts = [Struct.new(:body).new("[b]Hello[/b]")]
-->
```ruby
renderer = Markbridge.discourse_renderer(escape_hard_line_breaks: true)

posts.each do |post|
  result = Markbridge.bbcode_to_markdown(post.body, renderer:)
  puts result.markdown
end
```

The renderer stores no per-document state. Your custom handlers and tags should follow the same rule if you share them across calls or threads.

## Process one document at a time

Each conversion builds its AST and output in memory. For large collections, read and write one document at a time instead of keeping every result.

<!-- spec:before
require "csv"
csv_data = "id,body\n1,[b]Hello[/b]\n"
CSV.define_singleton_method(:foreach) do |_path, **opts, &block|
  CSV.parse(csv_data, **opts, &block)
end
-->
```ruby
require "csv"
require "markbridge/bbcode"

CSV.foreach("posts.csv", headers: true) do |row|
  result = Markbridge.bbcode_to_markdown(row["body"])
  puts result.markdown
end
```

## Parser limits

The BBCode parser limits nesting to 100 levels. Its built-in handlers preserve an opening tag as text when that limit is reached and record `depth_exceeded_count` in the diagnostics. A custom handler that calls `ParserState#push` without a token can raise `MaxDepthExceededError` at that limit.

Closing strategies search at most five levels when reconciling mismatched tags. These limits keep searches bounded on deeply nested input.

## How parsing works

- **BBCode:** the scanner uses byte offsets and integer checks for ASCII syntax. Offsets remain on character boundaries for multibyte input.
- **HTML and TextFormatter:** Nokogiri parses the input before Markbridge walks the document. Pass an existing Nokogiri node if your code has already parsed it.
- **MediaWiki:** the parser reads block syntax by line and uses a separate parser for inline markup.

Adjacent text nodes merge during AST construction. The renderer walks the resulting tree and uses a parent context for nested content.

## Measure your workload

Read input before timing if you want to measure conversion without file access:

<!-- spec:before
File.define_singleton_method(:readlines) { |_path, **| ["[b]Hello[/b]", "[i]world[/i]"] }
-->
```ruby
require "benchmark"
require "markbridge/bbcode"

inputs = File.readlines("corpus.txt", chomp: true)

Benchmark.bm do |benchmark|
  benchmark.report("conversion") do
    inputs.each { |input| Markbridge.bbcode_to_markdown(input) }
  end
end
```

On CRuby, compare runs with YJIT enabled:

```bash
ruby --yjit your_script.rb
```

JRuby and TruffleRuby have their own JIT compilers. Allow time for warmup and compare both startup time and sustained conversion speed.

## Repository benchmarks

Run benchmarks through `bin/bench-env`. It selects the fastest CPU cores and reports power and governor settings. Compare runs on AC power with the same governor.

```bash
bin/bench-env bundle exec ruby --yjit bench/bench.rb --isolated
DURATION=60 WINDOW=5 POSTS=2000 CORPUS=ascii bin/bench-env bundle exec ruby --yjit bench/sustained_bench.rb
DURATION=60 WINDOW=5 POSTS=2000 CORPUS=multi bin/bench-env bundle exec ruby --yjit bench/sustained_bench.rb
```

Run the ASCII and multibyte corpora in separate processes. See [Benchmark results](/concepts/benchmarks/) for recorded measurements and their limits.
