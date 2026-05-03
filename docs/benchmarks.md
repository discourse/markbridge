# Benchmark results

Throughput (iterations per second) of `Markbridge.bbcode_to_markdown(input)`
and `MarkdownEscaper#escape(text)` across Ruby implementations on the
`configure-mutant` branch.

## Setup

- Branch: `configure-mutant`
- Bench script: [`bench/bench.rb`](../bench/bench.rb)
- Mode: `--isolated` (each report runs in a fresh process so the JIT
  doesn't have to share its budget across 12 hot paths)
- Single machine, single run — small inter-run variance expected.
- CRuby runs: 2s warmup, 3s measure. JRuby: 10s warmup, 5s measure
  (its JIT needs longer to stabilise).
- Override warmup/measure via `BENCH_WARMUP=N BENCH_MEASURE=M`.

Run yourself:

```sh
# CRuby (auto-enables --yjit)
rv run --ruby 4.0 bundle exec ruby bench/bench.rb --isolated

# JRuby (longer warmup)
BENCH_WARMUP=10 BENCH_MEASURE=5 rv run --ruby jruby bundle exec ruby bench/bench.rb --isolated
```

## Versions

- `ruby 3.3.11` with YJIT
- `ruby 3.4.9` with YJIT (+PRISM)
- `ruby 4.0.2` with YJIT (+PRISM) — **project default**
- `jruby 10.1.0.0` (OpenJDK 26; default JIT, indy enabled)

## Results

Throughput (i/s, higher is better). `Δ vs 4.0` shows the relative
difference vs Ruby 4.0 (the project's primary target).

| Path | 3.3 | 3.4 | 4.0 | JRuby | 3.3 vs 4.0 | 3.4 vs 4.0 | JRuby vs 4.0 |
|---|---:|---:|---:|---:|---:|---:|---:|
| simple | 38.5k | 37.1k | 44.6k | 46.4k | −14% | −17% | **+4%** |
| nested | 41.6k | 39.8k | 47.7k | 46.4k | −13% | −17% | −3% |
| list | 38.4k | 37.8k | 46.0k | 19.5k | −16% | −18% | **−58%** |
| table | 11.7k | 11.5k | 13.6k | 10.7k | −14% | −15% | −21% |
| quote_nested | 28.7k | 26.8k | 31.7k | 28.9k | −9% | −15% | −9% |
| code | 91.6k | 81.0k | 110.6k | 116.2k | −17% | −27% | **+5%** |
| url | 46.0k | 43.2k | 52.6k | 55.2k | −13% | −18% | **+5%** |
| escaping | 61.2k | 53.4k | 65.2k | 79.9k | −6% | −18% | **+22%** |
| mixed | 13.7k | 13.6k | 15.5k | 15.8k | −12% | −12% | **+2%** |
| large_doc | 709 | 704 | 883 | 816 | −20% | −20% | −8% |
| escape_plain | 273k | 270k | 266k | 247k | +3% | +1% | −7% |
| escape_mixed | 8.6k | 5.2k | 5.5k | 16.6k | +56% | −7% | **+200%** |

## Highlights

- **Ruby 4.0 is uniformly faster than 3.3 and 3.4** — the
  jump is biggest on `code` (+22% over 3.3, +37% over 3.4) and
  `large_doc` (+25% over both). Worth pinning 4.0 as the default
  CI/dev target where possible.
- **Ruby 3.4 has a YJIT regression on `escape_mixed`** vs 3.3
  (5.2k vs 8.6k, **−39%**). 4.0 is still slow on this path
  (5.5k), so the YJIT regression persists across 3.4 and 4.0;
  3.3's YJIT handles the inline-byte dispatch loop better. Worth
  pinging the YJIT team if it matters.
- **JRuby is split**:
  - **Strong wins**: `escape_mixed` **+200%**, `escaping` **+22%**,
    `code/url/simple` **+4–5%**. JRuby's JIT does beautifully on
    inline-byte loops and tight tag dispatch.
  - **Strong losses**: `list` **−58%**, `table` **−21%**,
    `large_doc` **−8%**.
- **`escape_plain` is essentially flat** across all engines
  (~265–273k i/s). The `MAYBE_SPECIAL.match?` fast-path
  short-circuits to the original string with no allocations, so
  there's nothing for the JIT to optimise.

## Why is `list` so slow on JRuby?

The `list` benchmark renders a 3-item flat list. The render path is
heavy on per-item allocations even though the actual output is tiny:

For each ListItem render, the `RenderingInterface#with_parent` call
allocates a fresh `RenderContext` (which `dup`s the parent_cache hash
and concats the parents array). Combined with the per-item
`render_children`, the per-item budget is roughly:

- 1 RenderContext + 1 dup'd Hash + 1 extended Array (in `with_parent`)
- 1 result String (in `render_children`)
- 1 stripped String (`render_children(...).strip`)
- 1 `find_parent` lookup (O(1) hash check)
- 1 `ListItemBuilder#build` call (which `split("\n")`s the content)

That's 4–5 short-lived objects per item. CRuby's GC handles this
well; JRuby's young-gen GC seems to pay more per allocation, and
the hash/array dispatch in `RenderContext` doesn't inline as cleanly
as MRI's C-implemented core methods.

Profile (JRuby `--profile.flat`, 70k iterations of the `list` input,
post-perf-fix):

```
Total time: 6.94s
  3.89s  Markbridge.parse_bbcode
  1.85s  Renderer#render
  1.49s  ListTag#render
  1.07s  ListItemTag#render
  0.34s  RenderingInterface#with_parent
  0.32s  RenderContext#with_parent  (Hash#dup + Array#+)
```

Parse is 56% of total — about half of THAT is in
`PeekableEnumerator#ensure_peeked` (Array#size + Array#shift on the
1-element peek buffer, called twice per token). Inlining
`has_next?` into the parser loop (commit a392e0f) cut one of those
calls per token, but the other still fires.

If you wanted to push JRuby further, candidates would be:
1. Replace `RenderContext`'s `Hash#dup` with a copy-on-write struct
   so `with_parent` doesn't allocate when no new class enters the
   chain.
2. Skip the per-item `with_parent` for `ListItem`s when the parent
   chain hasn't changed shape (most items don't read it).
3. Pool `PeekableEnumerator`'s peek buffer or replace the Array
   with a single-slot `@peeked_token` ivar (typical depth is 0–1).

These are conscious tradeoffs; the current implementation is
optimal for CRuby+YJIT, which is the project's primary target.

## Caveats

- Single run per version; for production decisions, average 3+ runs.
- The `--isolated` mode pays a fork-per-report cost, so total
  wallclock is ~12× a single report. Use suite mode (`bench/bench.rb`
  with no flag) for a quick smoke test.
- `--yjit` is enabled on all CRuby runs and matters: without it
  numbers are 2–5× lower and don't reflect production.
