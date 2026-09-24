---
title: Benchmark results
description: Recorded throughput for CRuby, JRuby, and TruffleRuby, with the benchmark setup.
---

These recorded measurements show throughput (iterations per second) for `Markbridge.bbcode_to_markdown(input)`
and `MarkdownEscaper#escape(text)` across Ruby implementations on `main`.

## Machine

- Laptop with a 13th Gen Intel Core i9-13900H (6 performance cores,
  8 efficiency cores, 20 threads), Fedora 44.
- On AC power, `performance` CPU governor. On battery the CPU is
  throttled and the numbers cannot be compared with these.
- Every run pinned to the performance cores (0–11) with
  [`bin/bench-env`](https://github.com/discourse/markbridge/blob/main/bin/bench-env).

A laptop is not the fastest machine available, but it is close to what
many imports actually run on.

## Setup

- Branch: `fix-roundtrip-bugs` at `b94e1205` (the round-trip fixes and
  the performance work that follows them)
- Bench scripts: [`bench/bench.rb`](https://github.com/discourse/markbridge/blob/main/bench/bench.rb) for the short
  reports, [`bench/sustained_bench.rb`](https://github.com/discourse/markbridge/blob/main/bench/sustained_bench.rb)
  for the long corpus run further down.
- Mode: `--isolated` (each report runs in a fresh process so the JIT
  doesn't have to share its budget across all 10 reports)
- Single machine, single run per engine, all runs in one sitting —
  small inter-run variance expected.
- 10s warmup, 5s measure for every engine
  (`BENCH_WARMUP=10 BENCH_MEASURE=5`). The same settings for all
  engines keep the columns comparable. YJIT is warm in well under a
  second, so the long warmup costs CRuby nothing, while JRuby and
  TruffleRuby need it.

`bin/bench-env` picks the fastest cores of the machine, pins the
command to them, and prints whether the machine is on AC power and
which governor is active. It does not change either — that needs root:

```sh
sudo cpupower frequency-set -g performance
```

Run yourself:

```sh
# CRuby (auto-enables --yjit)
BENCH_WARMUP=10 BENCH_MEASURE=5 bin/bench-env rv run --ruby 4.0 bundle exec ruby bench/bench.rb --isolated

# JRuby
BENCH_WARMUP=10 BENCH_MEASURE=5 bin/bench-env rv run --ruby jruby bundle exec ruby bench/bench.rb --isolated

# TruffleRuby (installed by .silo.yml, or with `ruby-install truffleruby 40.0.0`)
BENCH_WARMUP=10 BENCH_MEASURE=5 bin/bench-env rv run --ruby truffleruby bundle exec ruby bench/bench.rb --isolated
```

## Versions

- `ruby 3.3.12` with YJIT
- `ruby 3.4.10` with YJIT (+PRISM)
- `ruby 4.0.7` with YJIT (+PRISM)
- `jruby 10.1.1.0` (Ruby 4.0.0; OpenJDK 27-ea+35, default JIT, indy
  enabled)
- `truffleruby 40.0.0` (Ruby 4.0.2; Oracle GraalVM Native)

## Results

Throughput (i/s, higher is better). `vs 4.0` shows the relative
difference from Ruby 4.0.7 with YJIT.

| Path | 3.3 | 3.4 | 4.0 | JRuby | TruffleRuby | 3.3 vs 4.0 | 3.4 vs 4.0 | JRuby vs 4.0 | TruffleRuby vs 4.0 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| simple | 57.2k | 53.1k | 87.0k | 51.1k | 305.4k | −34% | −39% | **−41%** | **+251%** |
| nested | 64.0k | 66.8k | 97.7k | 67.2k | 323.0k | −34% | −32% | −31% | **+231%** |
| list | 55.4k | 48.3k | 77.3k | 49.1k | 259.3k | −28% | −38% | −37% | **+235%** |
| table | 18.8k | 17.8k | 28.9k | 14.3k | 84.7k | −35% | −39% | **−50%** | **+193%** |
| quote_nested | 41.0k | 38.5k | 59.4k | 37.6k | 193.8k | −31% | −35% | −37% | **+226%** |
| code | 110.8k | 104.4k | 162.4k | 135.0k | 640.0k | −32% | −36% | −17% | **+294%** |
| url | 60.1k | 62.4k | 88.1k | 60.6k | 335.6k | −32% | −29% | −31% | **+281%** |
| escaping | 89.8k | 80.1k | 90.4k | 96.3k | 355.7k | −1% | −11% | +7% | **+294%** |
| escape_plain | 387.1k | 411.5k | 368.8k | 516.5k | see below | +5% | +12% | **+40%** | — |
| escape_mixed | 12.3k | 13.9k | 12.1k | 24.3k | 30.0k | +1% | +15% | **+100%** | **+148%** |

Run-to-run noise (benchmark-ips standard deviation) stayed at or below
3.1% on the CRuby versions. JRuby reached 5.0% and TruffleRuby 12.9%,
so read their single-digit differences with care.

:::note[`escape_plain` has no TruffleRuby number]
On this build TruffleRuby reports about 6.7M i/s for `escape_plain`,
which is 149 ns for a 4,200 character string, or roughly 28 GB/s. The
benchmark throws the return value away and the escaper allocates
nothing for plain text, so the compiler drops the call instead of
running it. The same number comes out on `main`, so it is a property of
the engine and this benchmark, not of a change in the escaper. The
other reports keep their result alive through an allocation and are not
affected.
:::

These measurements compare repeated conversions of small inputs. They do not predict the speed of a full application. The sustained run below uses a larger set of documents.

## Sustained corpus run

The reports above convert one small input each, and they are over in a
few seconds. `bench/sustained_bench.rb` measures the opposite case:
2000 forum-post-shaped documents (~1 KB each, built by
[`bench/corpus.rb`](https://github.com/discourse/markbridge/blob/main/bench/corpus.rb)) converted in a loop for 60
seconds per corpus, with the throughput of every 5 second window
printed. This is closer to a bulk migration than a micro report is.

:::note[The corpus gained glued emphasis]
The posts now also carry emphasis that sits directly against a word,
with content that ends in punctuation. CommonMark's flanking rules make
the renderer inspect the bytes around such a run, and the corpus did not
reach that code before. A post of that shape costs about 25% more, so
these numbers are the first ones measured on the harder corpus and are
lower than earlier published runs for that reason alone.
:::

```sh
DURATION=60 WINDOW=5 POSTS=2000 CORPUS=ascii bin/bench-env bundle exec ruby --yjit bench/sustained_bench.rb
```

Each corpus ran in its own process (`CORPUS=ascii`, then
`CORPUS=multi`). Running both in one process changes the JRuby result —
see the note at the end of this section. Steady state is the average of
the last three windows.

| Engine | ASCII | multibyte | ASCII vs 4.0 | multibyte vs 4.0 |
|---|---:|---:|---:|---:|
| ruby 3.3 | 16.4k | 11.6k | −12% | −3% |
| ruby 3.4 | 13.9k | 9.5k | −26% | −21% |
| ruby 4.0 | 18.6k | 12.0k | — | — |
| JRuby 10.1 | 15.2k | 9.7k | −19% | −19% |
| TruffleRuby 40 | 52.5k | 40.5k | **+182%** | **+237%** |

Posts per second. At steady state that is 18.3 MB/s for Ruby 4.0 and
51.6 MB/s for TruffleRuby on the ASCII corpus.

How long each engine needs to get there (ASCII corpus):

| Engine | first 5s window | steady | gain |
|---|---:|---:|---:|
| ruby 3.3 | 16.1k | 16.4k | +1% |
| ruby 3.4 | 13.7k | 13.9k | +1% |
| ruby 4.0 | 17.9k | 18.6k | +4% |
| JRuby 10.1 | 5.4k | 15.2k | **+180%** |
| TruffleRuby 40 | 25.2k | 52.5k | **+108%** |

On the multibyte corpus the same warmup is +145% for JRuby and +103%
for TruffleRuby.

- **The long run changes the ranking.** JRuby is 41% behind Ruby 4.0 on
  the `simple` micro report, but only 19% behind over the ASCII corpus.
  TruffleRuby's lead drops from 2.5x–3.9x to 2.8x (ASCII) and 3.4x
  (multibyte). The bigger and more varied the input, the smaller the
  distance — but TruffleRuby stays far ahead.
- **The JVM engines need seconds of warmup.** On this corpus JRuby
  reaches full speed after about 15 seconds and TruffleRuby after 20.
  CRuby is at full speed in the first window. Warmup depends on how
  much code the workload touches, so the micro reports, which run one
  small input, get there faster than this.
- **For a migration, read the column that matches the job.** A job that
  runs for minutes gets the steady numbers. A script that converts a
  few hundred posts and exits pays the warmup instead, and there Ruby
  4.0 is the fastest of the three.
- **Multibyte input costs every engine**, from −23% (TruffleRuby) to
  −36% (JRuby) against its own ASCII result. Ruby 4.0 loses 35%.

### JRuby slows down when both corpora share a process

A fresh JRuby process that only converts the multibyte corpus reaches
9.7k posts/s. The same corpus in a process that converted the ASCII
corpus first reaches either about the same or roughly half, and then
stays there for the rest of the run. Across three runs of that sequence
two landed at 4.7k and one at 9.9k.

CPU pinning is not the cause: a fresh multibyte process gives the same
number with and without it. CRuby does not show the effect, and
TruffleRuby loses only 5% to 8% in the same sequence.

That looks like a JIT decision made for ASCII strings that does not
recover once multibyte strings arrive at the same call sites. Real
imports convert mixed content, so a JRuby migration can land in either
state. Worth knowing before choosing JRuby for a large import, and
worth a bug report if someone wants to dig into it.

## Caveats

- Single run per engine; for production decisions, average 3+ runs.
- The machine ran a normal desktop session during the measurements,
  so a few percent of noise is expected, and the slow decline of
  some later windows may come from that. Keep an eye on the
  standard deviation and repeat a run that looks odd.
- The `--isolated` mode pays a fork-per-report cost, so total
  wallclock is ~10× a single report. Use suite mode (`bench/bench.rb`
  with no flag) for a quick smoke test.
- `--yjit` is enabled on all CRuby runs and matters: without it
  numbers are 2–5× lower and don't reflect production.
- TruffleRuby was measured with the Oracle GraalVM native build. The
  Community build is usually slower, and the JVM build starts slower
  but can reach higher peaks.
