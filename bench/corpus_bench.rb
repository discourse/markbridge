# frozen_string_literal: true

# Corpus benchmark with isolating variants. Complements bench/bench.rb:
# that file measures micro-inputs per feature; this one measures
# realistic ~1 KB forum posts and — more importantly — *isolates* cost
# centers by differencing variants (e.g. fresh minus shared = per-call
# setup cost; parse_only minus scan_only = handler/AST cost).
#
#   bundle exec ruby --yjit bench/corpus_bench.rb [variant ...]
#
# Reports best-of-N µs/post per corpus (ASCII and multibyte). Compare
# ascii vs multi within a variant to spot character-index pathologies.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "markbridge/all"
require_relative "corpus"

ROUNDS = Integer(ENV.fetch("ROUNDS", "12"))
WARMUP_ROUNDS = Integer(ENV.fetch("WARMUP_ROUNDS", "4"))

def best_of(corpus)
  best = Float::INFINITY
  WARMUP_ROUNDS.times { corpus.each { |post| yield post } }
  ROUNDS.times do
    GC.start
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    corpus.each { |post| yield post }
    dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    best = dt if dt < best
  end
  best
end

def report(name, corpus, &work)
  secs = best_of(corpus, &work)
  us_per_post = secs * 1_000_000 / corpus.size
  puts format(
         "%-22s %10.2f µs/post   (%.1f posts/ms)",
         name,
         us_per_post,
         corpus.size / (secs * 1000),
       )
end

# ASCII/multibyte corpus pair per source format.
CORPORA = { bbcode: -> { [Corpus.ascii, Corpus.multibyte] } }.freeze

# Each variant names the corpus pair it runs on and a runner that
# benchmarks one corpus under a label.
VARIANTS = {
  "fresh" => [
    :bbcode,
    lambda do |corpus, tag|
      report("fresh/#{tag}", corpus) { |post| Markbridge.bbcode_to_markdown(post) }
    end,
  ],
  # Tripwire for per-call setup churn: with the shared frozen defaults
  # this should match `fresh` — if the two diverge again, something
  # reintroduced construction on the no-customization path.
  "shared" => [
    :bbcode,
    lambda do |corpus, tag|
      handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
      renderer = Markbridge::Renderers::Discourse::Renderer.new
      report("shared/#{tag}", corpus) do |post|
        Markbridge.bbcode_to_markdown(post, handlers:, renderer:)
      end
    end,
  ],
  "parse_only" => [
    :bbcode,
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::BBCode::Parser.new
      report("parse_only/#{tag}", corpus) { |post| parser.parse(post) }
    end,
  ],
  "render_only" => [
    :bbcode,
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::BBCode::Parser.new
      asts = corpus.map { |post| parser.parse(post) }
      renderer = Markbridge::Renderers::Discourse::Renderer.new
      report("render_only/#{tag}", asts) { |ast| renderer.postprocessor.call(renderer.render(ast)) }
    end,
  ],
  "scan_only" => [
    :bbcode,
    lambda do |corpus, tag|
      report("scan_only/#{tag}", corpus) do |post|
        scanner = Markbridge::Parsers::BBCode::Scanner.new(post)
        nil while scanner.next_token
      end
    end,
  ],
}.freeze

requested = ARGV.empty? ? VARIANTS.keys : ARGV
puts "YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}  Ruby #{RUBY_VERSION}"
avg_ascii = Corpus.ascii.sum(&:bytesize) / Corpus.ascii.size
avg_multi = Corpus.multibyte.sum(&:bytesize) / Corpus.multibyte.size
puts "corpus: #{Corpus.ascii.size} posts, avg #{avg_ascii} B (ascii) / #{avg_multi} B (multibyte)"

requested.each do |name|
  corpus_key, runner = VARIANTS.fetch(name) { raise ArgumentError, "unknown variant #{name}" }
  ascii, multibyte = CORPORA.fetch(corpus_key).call
  runner.call(ascii, "ascii")
  runner.call(multibyte, "multi")
end
