# frozen_string_literal: true

# Benchmark suite for Markbridge end-to-end conversion paths.
#
# Usage:
#   bundle exec ruby --yjit bench/bench.rb
#
# Each report measures throughput (iterations per second) on a
# representative BBCode input shape. The escaper hot path gets its
# own group at the end for direct `Renderers::Discourse::MarkdownEscaper#escape`
# measurements.
#
# Notes:
# - `--yjit` is important; YJIT warmup materially changes numbers.
# - `benchmark-ips` warmup is set to 2s / measurement 3s. Shorter
#   warmup under-reports YJIT-friendly code.
# - Isolated micro-benchmarks may diverge from these numbers because
#   YJIT's code cache is shared across the suite; running 12 reports
#   back-to-back can cause eviction that a single-report run avoids.
#   Compare branch-to-branch at the suite level, not absolute numbers.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "markbridge/all"
require "benchmark/ips"

SIMPLE = "[b]bold[/b] [i]italic[/i] [u]underline[/u] text"

NESTED = "[b]bold [i]italic [u]underline[/u][/i][/b]"

LIST = <<~BBCODE
  [list]
  [*]First item
  [*]Second item
  [*]Third item
  [/list]
BBCODE

TABLE = <<~BBCODE
  [table]
  [tr][th]A[/th][th]B[/th][th]C[/th][/tr]
  [tr][td]1[/td][td]2[/td][td]3[/td][/tr]
  [tr][td]4[/td][td]5[/td][td]6[/td][/tr]
  [/table]
BBCODE

QUOTE = <<~BBCODE
  [quote="alice"]
  Some quoted text with [b]bold[/b] content.
  [quote="bob"]
  Nested quote.
  [/quote]
  [/quote]
BBCODE

CODE = "[code]def hello\n  puts 'hello world'\nend[/code]"

URL = "Check out [url=https://example.com]this link[/url] and [url=https://foo.com]another[/url]"

MIXED = [SIMPLE, NESTED, LIST, TABLE, QUOTE, CODE, URL].join("\n\n")

ESCAPING =
  "Text with *asterisks* and _underscores_ and `backticks` and [brackets] and |pipes| " \
    "\n\n# Not a heading\n---\nnot a rule"

LARGE = (MIXED + "\n\n") * 20

ESCAPER = Markbridge::Renderers::Discourse::MarkdownEscaper.new
PLAIN_TEXT = "This is plain text with no special chars. " * 100
MIXED_ESCAPE_TEXT = "Text with *stars*, _underscores_, `code`, and [brackets]. " * 50

Benchmark.ips do |x|
  x.config(time: 3, warmup: 2)

  x.report("simple") { Markbridge.bbcode_to_markdown(SIMPLE) }
  x.report("nested") { Markbridge.bbcode_to_markdown(NESTED) }
  x.report("list") { Markbridge.bbcode_to_markdown(LIST) }
  x.report("table") { Markbridge.bbcode_to_markdown(TABLE) }
  x.report("quote_nested") { Markbridge.bbcode_to_markdown(QUOTE) }
  x.report("code") { Markbridge.bbcode_to_markdown(CODE) }
  x.report("url") { Markbridge.bbcode_to_markdown(URL) }
  x.report("mixed") { Markbridge.bbcode_to_markdown(MIXED) }
  x.report("escaping") { Markbridge.bbcode_to_markdown(ESCAPING) }
  x.report("large_doc") { Markbridge.bbcode_to_markdown(LARGE) }

  x.report("escape_plain") { ESCAPER.escape(PLAIN_TEXT) }
  x.report("escape_mixed") { ESCAPER.escape(MIXED_ESCAPE_TEXT) }
end
