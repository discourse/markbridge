# frozen_string_literal: true

# Corpus benchmark with isolating variants. Complements bench/bench.rb:
# that file measures micro-inputs per feature; this one measures
# realistic ~1 KB forum posts and — more importantly — *isolates* cost
# centers by differencing variants (e.g. fresh minus shared = per-call
# setup cost; parse_only minus scan_only = handler/AST cost).
#
#   bundle exec ruby --yjit bench/corpus_bench.rb [variant ...]
#
# Variants:
#   fresh        - Markbridge.bbcode_to_markdown(input)  (default API)
#   shared       - shared HandlerRegistry + Renderer across calls
#   parse_only   - parser.parse(input) with shared registry
#   render_only  - render pre-parsed ASTs with shared renderer
#   scan_only    - Scanner token loop only
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

VARIANTS = {
  "fresh" =>
    lambda do |corpus, tag|
      report("fresh/#{tag}", corpus) { |post| Markbridge.bbcode_to_markdown(post) }
    end,
  "shared" =>
    lambda do |corpus, tag|
      handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
      renderer = Markbridge::Renderers::Discourse::Renderer.new
      report("shared/#{tag}", corpus) do |post|
        Markbridge.bbcode_to_markdown(post, handlers:, renderer:)
      end
    end,
  "parse_only" =>
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::BBCode::Parser.new
      report("parse_only/#{tag}", corpus) { |post| parser.parse(post) }
    end,
  "render_only" =>
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::BBCode::Parser.new
      asts = corpus.map { |post| parser.parse(post) }
      renderer = Markbridge::Renderers::Discourse::Renderer.new
      report("render_only/#{tag}", asts) { |ast| renderer.postprocessor.call(renderer.render(ast)) }
    end,
  "scan_only" =>
    lambda do |corpus, tag|
      report("scan_only/#{tag}", corpus) do |post|
        scanner = Markbridge::Parsers::BBCode::Scanner.new(post)
        nil while scanner.next_token
      end
    end,
}.freeze

requested = ARGV.empty? ? VARIANTS.keys : ARGV
puts "YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}  Ruby #{RUBY_VERSION}"
avg_ascii = Corpus.ascii.sum(&:bytesize) / Corpus.ascii.size
avg_multi = Corpus.multibyte.sum(&:bytesize) / Corpus.multibyte.size
puts "corpus: #{Corpus.ascii.size} posts, avg #{avg_ascii} B (ascii) / #{avg_multi} B (multibyte)"

requested.each do |variant|
  runner = VARIANTS.fetch(variant)
  runner.call(Corpus.ascii, "ascii")
  runner.call(Corpus.multibyte, "multi")
end
