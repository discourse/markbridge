# frozen_string_literal: true

# Corpus benchmark with isolating variants. Complements bench/bench.rb:
# that file measures micro-inputs per feature; this one measures
# realistic ~1 KB forum posts and — more importantly — *isolates* cost
# centers by differencing variants (e.g. fresh minus shared = per-call
# setup cost; parse_only minus scan_only = handler/AST cost; *_parse
# minus *_walk = nokogiri's share).
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

# A violation-heavy variant of a corpus: prepends a few degenerate
# constructs (linked image, nested links, block-in-link) to each post so
# the normalizer's worst case — including the destination-stack rewalk on
# moved subtrees — is exercised on realistic surrounding text.
def build_heavy(corpus)
  violating =
    "[url=https://ex.com/a][img]https://ex.com/i.png[/img][/url] " \
      "[url=https://a.com][url=https://b.com]x[/url][/url] " \
      "[url=https://ex.com][quote]q[/quote][/url] "
  corpus.map { |post| violating + post }
end

# ASCII/multibyte corpus pair per source format.
CORPORA = {
  bbcode: -> { [Corpus.ascii, Corpus.multibyte] },
  bbcode_heavy: -> { [build_heavy(Corpus.ascii), build_heavy(Corpus.multibyte)] },
  mediawiki: -> { [Corpus.mediawiki, Corpus.mediawiki_multibyte] },
  html: -> { [Corpus.html, Corpus.html_multibyte] },
  text_formatter: -> { [Corpus.text_formatter, Corpus.text_formatter_multibyte] },
}.freeze

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
  # The default-on gate: the normalization walk over violation-free trees
  # in isolation (pre-parsed ASTs; the clean corpus never mutates, so every
  # round measures the same zero-violation traversal). Compare against zero.
  "norm_only" => [
    :bbcode,
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::BBCode::Parser.new
      asts = corpus.map { |post| parser.parse(post) }
      normalizer = Markbridge::Normalizer.shared_for(:discourse)
      report("norm_only/#{tag}", asts) { |ast| normalizer.normalize(ast) }
    end,
  ],
  # End-to-end baseline with normalization off; `fresh` minus this is the
  # zero-violation overhead of default-on normalization.
  "fresh_no_norm" => [
    :bbcode,
    lambda do |corpus, tag|
      report("fresh_no_norm/#{tag}", corpus) do |post|
        Markbridge.bbcode_to_markdown(post, normalize: false)
      end
    end,
  ],
  # Worst-case bound: end-to-end over a violation-heavy corpus, with and
  # without normalization (the difference is the mutation + rewalk cost).
  "norm_heavy" => [
    :bbcode_heavy,
    lambda do |corpus, tag|
      report("norm_heavy/#{tag}", corpus) { |post| Markbridge.bbcode_to_markdown(post) }
    end,
  ],
  "norm_heavy_off" => [
    :bbcode_heavy,
    lambda do |corpus, tag|
      report("norm_heavy_off/#{tag}", corpus) do |post|
        Markbridge.bbcode_to_markdown(post, normalize: false)
      end
    end,
  ],
  "mw_fresh" => [
    :mediawiki,
    lambda do |corpus, tag|
      report("mw_fresh/#{tag}", corpus) { |post| Markbridge.mediawiki_to_markdown(post) }
    end,
  ],
  "mw_parse" => [
    :mediawiki,
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::MediaWiki::Parser.new
      report("mw_parse/#{tag}", corpus) { |post| parser.parse(post) }
    end,
  ],
  "html_fresh" => [
    :html,
    lambda do |corpus, tag|
      report("html_fresh/#{tag}", corpus) { |post| Markbridge.html_to_markdown(post) }
    end,
  ],
  "html_parse" => [
    :html,
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::HTML::Parser.new
      report("html_parse/#{tag}", corpus) { |post| parser.parse(post) }
    end,
  ],
  # The Ruby tree walk alone (pre-parsed input); html_parse minus
  # html_walk = nokogiri's share.
  "html_walk" => [
    :html,
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::HTML::Parser.new
      fragments = corpus.map { |post| Nokogiri::HTML.fragment(post) }
      report("html_walk/#{tag}", fragments) { |fragment| parser.parse(fragment) }
    end,
  ],
  "html_nokogiri" => [
    :html,
    lambda do |corpus, tag|
      report("html_nokogiri/#{tag}", corpus) { |post| Nokogiri::HTML.fragment(post) }
    end,
  ],
  "tf_fresh" => [
    :text_formatter,
    lambda do |corpus, tag|
      report("tf_fresh/#{tag}", corpus) { |post| Markbridge.text_formatter_xml_to_markdown(post) }
    end,
  ],
  "tf_parse" => [
    :text_formatter,
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::TextFormatter::Parser.new
      report("tf_parse/#{tag}", corpus) { |post| parser.parse(post) }
    end,
  ],
  "tf_walk" => [
    :text_formatter,
    lambda do |corpus, tag|
      parser = Markbridge::Parsers::TextFormatter::Parser.new
      docs = corpus.map { |post| Nokogiri.XML(post) }
      report("tf_walk/#{tag}", docs) { |doc| parser.parse(doc) }
    end,
  ],
  "tf_nokogiri" => [
    :text_formatter,
    lambda { |corpus, tag| report("tf_nokogiri/#{tag}", corpus) { |post| Nokogiri.XML(post) } },
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
