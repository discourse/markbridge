# frozen_string_literal: true

# Allocation profiler for the BBCode → Markdown pipeline.
#
#   bundle exec ruby bench/alloc_profile.rb [fresh|shared|parse_only|render_only] [ascii|multi]
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

variant = ARGV[0] || "fresh"
which = ARGV[1] || "ascii"
corpus =
  if variant.start_with?("mw_")
    which == "multi" ? Corpus.mediawiki_multibyte : Corpus.mediawiki
  elsif variant.start_with?("html_")
    which == "multi" ? Corpus.html_multibyte : Corpus.html
  elsif variant.start_with?("tf_")
    which == "multi" ? Corpus.text_formatter_multibyte : Corpus.text_formatter
  else
    which == "multi" ? Corpus.multibyte : Corpus.ascii
  end

handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
parser = Markbridge::Parsers::BBCode::Parser.new(handlers:)
renderer = Markbridge::Renderers::Discourse::Renderer.new
asts = corpus.map { |post| parser.parse(post) } if variant == "render_only"

mw_parser = Markbridge::Parsers::MediaWiki::Parser.new
html_parser = Markbridge::Parsers::HTML::Parser.new
tf_parser = Markbridge::Parsers::TextFormatter::Parser.new

work =
  case variant
  when "fresh"
    ->(i) { Markbridge.bbcode_to_markdown(corpus[i]) }
  when "shared"
    ->(i) { Markbridge.bbcode_to_markdown(corpus[i], handlers:, renderer:) }
  when "parse_only"
    ->(i) { parser.parse(corpus[i]) }
  when "render_only"
    ->(i) { renderer.postprocessor.call(renderer.render(asts[i])) }
  when "mw_fresh"
    ->(i) { Markbridge.mediawiki_to_markdown(corpus[i]) }
  when "mw_parse"
    ->(i) { mw_parser.parse(corpus[i]) }
  when "html_fresh"
    ->(i) { Markbridge.html_to_markdown(corpus[i]) }
  when "html_parse"
    ->(i) { html_parser.parse(corpus[i]) }
  when "html_walk"
    fragments = corpus.map { |post| Nokogiri::HTML.fragment(post) }
    ->(i) { html_parser.parse(fragments[i]) }
  when "tf_fresh"
    ->(i) { Markbridge.text_formatter_xml_to_markdown(corpus[i]) }
  when "tf_parse"
    ->(i) { tf_parser.parse(corpus[i]) }
  when "tf_walk"
    docs = corpus.map { |post| Nokogiri.XML(post) }
    ->(i) { tf_parser.parse(docs[i]) }
  else
    raise ArgumentError, "unknown variant #{variant}"
  end

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
