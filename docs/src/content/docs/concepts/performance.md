---
title: Performance
description: Reuse your configuration, process large inputs, and measure conversion speed.
---

Markbridge is fast enough that most projects never have to think about it: a typical forum post converts in well under a tenth of a millisecond (see [Benchmark results](/concepts/benchmarks/)). This page is for the cases where it matters, like a migration with millions of posts. It covers what to reuse, the limits the parsers have, and how to measure your own input.

## Reuse your configuration

Building a renderer or a handler registry takes about as long as converting a short post. Build them once, outside the loop:

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

A renderer keeps nothing from one document to the next. It does keep state while a render call runs, so use one renderer per thread. Your own handlers and tags should keep no state between calls either.

Without options there is nothing to build: the defaults are created once per process and frozen. To change a default registry, get a copy with `.default` or `.build_from_default`.

## Process one document at a time

A conversion holds its AST and its output in memory. With many documents, read one, convert it and write it, and do not collect the results:

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

The parsers have limits, so that hostile or broken input cannot make a conversion slow:

- **The BBCode parser nests at most 100 levels.** A tag that opens deeper than that stays in the output as text, and `depth_exceeded_count` in the diagnostics counts it. Your own handler can raise `MaxDepthExceededError` at the limit if it calls `ParserState#push` without the token.
- **The closing strategies look at most five levels up or ahead** when they match a closing tag with an open element.

## Do not parse twice

The HTML and TextFormatter parsers take a Nokogiri node in place of a String. If your code already parsed the input, for example to rewrite some elements, pass the node on.

## Measure your workload

Numbers from someone else's machine and input say little about yours. The size of the documents, how deep they nest, your own handlers and the Ruby you run all change the result. Measure with your own content, and read it into memory first, so the time for reading files is not part of the number:

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

JRuby and TruffleRuby compile while the program runs and need time to get fast. For a short script the start time counts, for a long migration the speed after warmup does. Measure both.

## Repository benchmarks

This part is for work on Markbridge itself. Run every benchmark through `bin/bench-env`. It runs the process on the fastest CPU cores and prints the power source and the CPU governor. Only compare runs on AC power with the same governor.

```bash
bin/bench-env bundle exec ruby --yjit bench/bench.rb --isolated
DURATION=60 WINDOW=5 POSTS=2000 CORPUS=ascii bin/bench-env bundle exec ruby --yjit bench/sustained_bench.rb
DURATION=60 WINDOW=5 POSTS=2000 CORPUS=multi bin/bench-env bundle exec ruby --yjit bench/sustained_bench.rb
```

Run the ASCII and the multibyte corpus in separate processes. [Benchmark results](/concepts/benchmarks/) has the recorded numbers and says what they do and do not show.
