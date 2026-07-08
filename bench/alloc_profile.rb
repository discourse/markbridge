# frozen_string_literal: true

# Allocation profiler for the conversion pipelines.
#
#   bundle exec ruby bench/alloc_profile.rb [variant] [ascii|multi]
#
# Two instruments:
#
# 1. Headline: GC.stat(:total_allocated_objects) delta per post, averaged
#    over the whole corpus. Use this number to compare branches.
# 2. Detail: ObjectSpace.trace_object_allocations with GC disabled,
#    grouped by file:line and by class, ranked. This names the exact
#    allocation site — profile before optimizing, the ranking is usually
#    not what intuition predicts.
#
# Note: wall-clock benchmarks understate allocation wins — fewer
# allocations also mean fewer GC cycles under real workloads.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "markbridge/all"
require "objspace"
require_relative "corpus"

# ASCII/multibyte corpus pair per source format.
CORPORA = {
  bbcode: -> { [Corpus.ascii, Corpus.multibyte] },
  mediawiki: -> { [Corpus.mediawiki, Corpus.mediawiki_multibyte] },
  html: -> { [Corpus.html, Corpus.html_multibyte] },
  text_formatter: -> { [Corpus.text_formatter, Corpus.text_formatter_multibyte] },
}.freeze

# Each variant names the corpus pair it runs on and a builder that
# receives the corpus and returns the per-post work lambda.
VARIANTS = {
  "fresh" => [:bbcode, ->(corpus) { ->(i) { Markbridge.bbcode_to_markdown(corpus[i]) } }],
  "shared" => [
    :bbcode,
    lambda do |corpus|
      handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
      renderer = Markbridge::Renderers::Discourse::Renderer.new
      ->(i) { Markbridge.bbcode_to_markdown(corpus[i], handlers:, renderer:) }
    end,
  ],
  "parse_only" => [
    :bbcode,
    lambda do |corpus|
      parser = Markbridge::Parsers::BBCode::Parser.new
      ->(i) { parser.parse(corpus[i]) }
    end,
  ],
  "render_only" => [
    :bbcode,
    lambda do |corpus|
      parser = Markbridge::Parsers::BBCode::Parser.new
      asts = corpus.map { |post| parser.parse(post) }
      renderer = Markbridge::Renderers::Discourse::Renderer.new
      ->(i) { renderer.postprocessor.call(renderer.render(asts[i])) }
    end,
  ],
  "mw_fresh" => [:mediawiki, ->(corpus) { ->(i) { Markbridge.mediawiki_to_markdown(corpus[i]) } }],
  "mw_parse" => [
    :mediawiki,
    lambda do |corpus|
      parser = Markbridge::Parsers::MediaWiki::Parser.new
      ->(i) { parser.parse(corpus[i]) }
    end,
  ],
  "html_fresh" => [:html, ->(corpus) { ->(i) { Markbridge.html_to_markdown(corpus[i]) } }],
  "html_parse" => [
    :html,
    lambda do |corpus|
      parser = Markbridge::Parsers::HTML::Parser.new
      ->(i) { parser.parse(corpus[i]) }
    end,
  ],
  "html_walk" => [
    :html,
    lambda do |corpus|
      parser = Markbridge::Parsers::HTML::Parser.new
      fragments = corpus.map { |post| Nokogiri::HTML.fragment(post) }
      ->(i) { parser.parse(fragments[i]) }
    end,
  ],
  "tf_fresh" => [
    :text_formatter,
    ->(corpus) { ->(i) { Markbridge.text_formatter_xml_to_markdown(corpus[i]) } },
  ],
  "tf_parse" => [
    :text_formatter,
    lambda do |corpus|
      parser = Markbridge::Parsers::TextFormatter::Parser.new
      ->(i) { parser.parse(corpus[i]) }
    end,
  ],
  "tf_walk" => [
    :text_formatter,
    lambda do |corpus|
      parser = Markbridge::Parsers::TextFormatter::Parser.new
      docs = corpus.map { |post| Nokogiri.XML(post) }
      ->(i) { parser.parse(docs[i]) }
    end,
  ],
}.freeze

variant = ARGV[0] || "fresh"
which = ARGV[1] || "ascii"

corpus_key, builder = VARIANTS.fetch(variant) { raise ArgumentError, "unknown variant #{variant}" }
ascii, multibyte = CORPORA.fetch(corpus_key).call
corpus = which == "multi" ? multibyte : ascii
work = builder.call(corpus)
n = corpus.size

# Warm up (shared-default memoization, autoloads)
3.times { |k| work.call(k) }

GC.start
before = GC.stat(:total_allocated_objects)
n.times { |i| work.call(i) }
after = GC.stat(:total_allocated_objects)
puts "#{variant}/#{which}: #{(after - before) / n} objects/post (#{n} posts)"

GC.start
GC.disable
ObjectSpace.trace_object_allocations { 20.times { |i| work.call(i) } }

site_counts = Hash.new(0)
class_counts = Hash.new(0)
ObjectSpace.each_object do |obj|
  file = ObjectSpace.allocation_sourcefile(obj)
  next unless file&.include?("markbridge")

  line = ObjectSpace.allocation_sourceline(obj)
  site_counts["#{file.sub(%r{.*/markbridge/}, "")}:#{line}"] += 1
  class_counts[obj.class.to_s] += 1
end
GC.enable

puts "\nTop allocation sites (20 posts):"
site_counts.sort_by { |_, c| -c }.first(40).each { |site, c| puts format("  %6d  %s", c, site) }
puts "\nTop classes:"
class_counts.sort_by { |_, c| -c }.first(15).each { |k, c| puts format("  %6d  %s", c, k) }
