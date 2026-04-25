# Benchmark results

Throughput (iterations per second) of `Markbridge.bbcode_to_markdown(input)`
and `MarkdownEscaper#escape(text)` across Ruby implementations on the
`configure-mutant` branch.

## Setup

- Branch: `configure-mutant`
- Bench script: [`bench/bench.rb`](../bench/bench.rb)
- Mode: `--isolated` (each report runs in a fresh process so the JIT
  doesn't have to share its budget across 12 hot paths)
- Warmup: 2s, measure: 3s per report (`benchmark-ips`)
- Single machine, single run — small inter-run variance expected.

Run yourself:

```sh
rv run --ruby 3.4 bundle exec ruby bench/bench.rb --isolated
rv run --ruby jruby bundle exec ruby bench/bench.rb --isolated
```

The script auto-detects engine and only passes `--yjit` on CRuby.

## Versions

- `ruby 3.3.11` with YJIT
- `ruby 3.4.9` with YJIT (+PRISM)
- `ruby 4.0.2` with YJIT (+PRISM)
- `jruby 10.1.0.0` (OpenJDK 26; default JIT, indy enabled)

## Results

Throughput (i/s, higher is better). `Δ vs 3.4` shows the relative
difference vs Ruby 3.4.9 (the project's primary target).

| Path | 3.3 | 3.4 | 4.0 | JRuby | 4.0 vs 3.4 | JRuby vs 3.4 |
|---|---:|---:|---:|---:|---:|---:|
| simple | 37.6k | 36.4k | 44.1k | 43.7k | **+21%** | +20% |
| nested | 40.1k | 38.6k | 46.5k | 43.5k | **+20%** | +13% |
| list | 36.3k | 36.2k | 43.8k | 15.1k | **+21%** | **−58%** |
| table | 11.4k | 11.0k | 13.4k | 10.1k | +21% | −7% |
| quote_nested | 28.0k | 26.2k | 30.8k | 27.9k | +18% | +6% |
| code | 84.8k | 78.3k | 107.5k | 117.5k | **+37%** | **+50%** |
| url | 44.1k | 42.6k | 51.1k | 54.7k | +20% | +28% |
| escaping | 59.9k | 52.3k | 63.5k | 78.7k | +21% | **+50%** |
| mixed | 13.4k | 13.2k | 15.4k | 9.5k | +17% | −28% |
| large_doc | 685 | 682 | 859 | 466 | +26% | −32% |
| escape_plain | 271k | 267k | 265k | 238k | −1% | −11% |
| escape_mixed | 8.6k | 5.2k | 5.5k | 16.6k | +6% | **+218%** |

## Highlights

- **Ruby 4.0 is consistently faster than 3.4** — roughly **+20% across
  the board** on the conversion pipeline, jumping to **+37%** on
  `code`. No path regresses. Worth flagging: when 4.x lands, this
  branch's residual ~4% gap vs main on Ruby 3.4 disappears.
- **`escape_mixed` regressed in Ruby 3.4 vs 3.3** (5.2k vs 8.6k —
  **−39%**). Looks like a YJIT regression for the specific pattern in
  `MarkdownEscaper#escape_inline`; it doesn't reproduce on 4.0 (5.5k,
  same as 3.4) but is gone vs 3.3. Worth pinging the YJIT team.
- **JRuby is dramatic in both directions**:
  - **+218% on `escape_mixed`** (16.6k vs CRuby 3.4's 5.2k), **+50% on
    `escaping`**, **+50% on `code`** — JRuby's JIT does beautifully on
    the inline-byte loops.
  - **−58% on `list`**, **−32% on `large_doc`**, **−28% on `mixed`** —
    paths heavy in object allocation / context-walking suffer. The
    `RenderContext` parent-chain caching that helps CRuby seems to
    cost more than it saves on JRuby (object identity / hash lookups).
  - **High variance** (±10–30%) on several paths — JIT warmup instability;
    longer warmup would smooth this out.
- **`escape_plain` is essentially flat** across all CRuby versions
  (~268k i/s). The fast-path `return text unless MAYBE_SPECIAL.match?`
  in `escape` short-circuits to the original string with no
  allocation, so there's nothing for the JIT to optimize.

## Caveats

- Single run per version; for production decisions, average 3+ runs.
- JRuby benefits from longer warmup than `benchmark-ips`'s 2s default;
  numbers there should be treated as a lower bound.
- The `--isolated` mode pays a fork-per-report cost, so total wallclock
  is ~12× a single report. Use suite mode (`bench/bench.rb` with no
  flag) for a quick smoke test.
- `--yjit` is enabled on all CRuby runs and matters: without it
  numbers are 2–5× lower and don't reflect production.
