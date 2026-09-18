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

- Branch: `main`
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

- `ruby 3.3.11` with YJIT
- `ruby 3.4.9` with YJIT (+PRISM)
- `ruby 4.0.5` with YJIT (+PRISM)
- `jruby 10.1.0.0` (Ruby 4.0.0; OpenJDK 27-ea, default JIT, indy enabled)
- `truffleruby 40.0.0` (Ruby 4.0.2; GraalVM CE Native — the build
  `ruby/setup-ruby` installs for `truffleruby`)

## Results

Throughput (i/s, higher is better). `vs 4.0` shows the relative
difference from Ruby 4.0.5 with YJIT.

| Path | 3.3 | 3.4 | 4.0 | JRuby | TruffleRuby | 3.3 vs 4.0 | 3.4 vs 4.0 | JRuby vs 4.0 | TruffleRuby vs 4.0 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| simple | 61.5k | 60.6k | 81.0k | 59.6k | 314.8k | −24% | −25% | −26% | **+289%** |
| nested | 70.1k | 64.8k | 88.8k | 62.5k | 321.4k | −21% | −27% | −30% | **+262%** |
| list | 56.1k | 52.9k | 71.3k | 49.1k | 253.2k | −21% | −26% | −31% | **+255%** |
| table | 18.1k | 19.1k | 26.2k | 16.4k | 84.4k | −31% | −27% | **−37%** | **+222%** |
| quote_nested | 42.6k | 41.6k | 52.3k | 39.5k | 193.6k | −19% | −20% | −24% | **+270%** |
| code | 125.7k | 118.1k | 162.2k | 134.1k | 585.7k | −23% | −27% | −17% | **+261%** |
| url | 67.0k | 69.0k | 88.4k | 65.9k | 367.3k | −24% | −22% | −26% | **+315%** |
| escaping | 86.9k | 78.1k | 93.7k | 102.9k | 318.7k | −7% | −17% | **+10%** | **+240%** |
| escape_plain | 396.4k | 403.1k | 397.9k | 516.8k | 583.8k | −0% | +1% | **+30%** | **+47%** |
| escape_mixed | 11.4k | 7.5k | 7.8k | 16.4k | 36.5k | **+47%** | −4% | **+111%** | **+371%** |

Run-to-run noise (benchmark-ips standard deviation) stayed at or below
3.2% on the CRuby versions. JRuby and TruffleRuby reached 8.4% and
8.1%, so read their single-digit differences with care.

These measurements compare repeated conversions of small inputs. They do not predict the speed of a full application. The sustained run below uses a larger set of documents.

## Sustained corpus run

The reports above convert one small input each, and they are over in a
few seconds. `bench/sustained_bench.rb` measures the opposite case:
2000 forum-post-shaped documents (~1 KB each, built by
[`bench/corpus.rb`](https://github.com/discourse/markbridge/blob/main/bench/corpus.rb)) converted in a loop for 60
seconds per corpus, with the throughput of every 5 second window
printed. This is closer to a bulk migration than a micro report is.

```sh
DURATION=60 WINDOW=5 POSTS=2000 CORPUS=ascii bin/bench-env bundle exec ruby --yjit bench/sustained_bench.rb
```

Each corpus ran in its own process (`CORPUS=ascii`, then
`CORPUS=multi`). Running both in one process changes the JRuby result —
see the note at the end of this section. Steady state is the average of
the last three windows.

| Engine | ASCII | multibyte | ASCII vs 4.0 | multibyte vs 4.0 |
|---|---:|---:|---:|---:|
| ruby 3.3 | 19.6k | 13.7k | −9% | −4% |
| ruby 3.4 | 16.5k | 11.9k | −23% | −17% |
| ruby 4.0 | 21.4k | 14.3k | — | — |
| JRuby 10.1 | 19.8k | 11.6k | −8% | −19% |
| TruffleRuby 40 | 58.2k | 47.4k | **+171%** | **+232%** |

Posts per second. At steady state that is 20.0 MB/s for Ruby 4.0 and
54.2 MB/s for TruffleRuby on the ASCII corpus.

How long each engine needs to get there (ASCII corpus):

| Engine | first 5s window | steady | gain |
|---|---:|---:|---:|
| ruby 3.3 | 19.5k | 19.6k | +1% |
| ruby 3.4 | 17.0k | 16.5k | −3% |
| ruby 4.0 | 22.4k | 21.4k | −4% |
| JRuby 10.1 | 8.9k | 19.8k | **+122%** |
| TruffleRuby 40 | 21.2k | 58.2k | **+175%** |

On the multibyte corpus the same warmup is +148% for JRuby and +266%
for TruffleRuby.

- **The long run changes the ranking.** JRuby is 26% behind Ruby 4.0 on
  the `simple` micro report, but only 8% behind over the ASCII corpus.
  TruffleRuby's lead drops from 2.2x–4.2x to 2.7x (ASCII) and 3.3x
  (multibyte). The bigger and more varied the input, the smaller the
  distance — but TruffleRuby stays far ahead.
- **The JVM engines need seconds of warmup.** On this corpus JRuby
  reaches full speed after about 10 seconds and TruffleRuby after 15.
  CRuby is at full speed in the first window. Warmup depends on how
  much code the workload touches, so the micro reports, which run one
  small input, get there faster than this.
- **For a migration, read the column that matches the job.** A job that
  runs for minutes gets the steady numbers. A script that converts a
  few hundred posts and exits pays the warmup instead, and there Ruby
  4.0 is the fastest of the three.
- **Multibyte input costs every engine**, from −19% (TruffleRuby) to
  −41% (JRuby) against its own ASCII result. Ruby 4.0 loses 33%.

### JRuby slows down when both corpora share a process

A fresh JRuby process that only converts the multibyte corpus reaches
11.6k posts/s. The same corpus in a process that converted the ASCII
corpus first reaches either the same 11.8k or about 6.0k, and then
stays there for the rest of the run. Across six runs of that sequence —
pinned and unpinned, on battery and on AC — four landed near 6.0k and
two near 11.8k.

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
- TruffleRuby was measured with the Community native build. The
  Oracle GraalVM build (`truffleruby+graalvm`) is usually faster
  still, and the JVM build starts slower but can reach higher peaks.
