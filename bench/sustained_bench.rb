# frozen_string_literal: true

# Long-running corpus benchmark.
#
# bench/bench.rb measures one small input per report, and
# bench/corpus_bench.rb takes the best of a few rounds over 200 posts.
# Both are short. JRuby and TruffleRuby need seconds before their JIT
# reaches full speed, so a short benchmark reports them while they are
# still warming up.
#
# This script converts a large corpus for a fixed time and prints the
# throughput of each time window. The windows show when an engine stops
# improving. The summary compares the first window with the steady
# state, which is the number that matters for a bulk migration.
#
#   bin/bench-env bundle exec ruby --yjit bench/sustained_bench.rb
#   DURATION=120 POSTS=5000 bin/bench-env bundle exec ruby bench/sustained_bench.rb
#
# bin/bench-env pins the process to the fastest cores of the machine
# and reports the power and governor state. A run on battery is
# throttled and does not compare with one on AC power.
#
# Env:
#   DURATION  seconds per corpus (default 60)
#   WINDOW    seconds per reported window (default 5)
#   POSTS     posts per corpus (default 2000)
#   CORPUS    ascii, multi or both (default both)

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "markbridge/all"
require_relative "corpus"

DURATION = Float(ENV.fetch("DURATION", "60"))
WINDOW = Float(ENV.fetch("WINDOW", "5"))
POSTS = Integer(ENV.fetch("POSTS", "2000"))
CORPUS = ENV.fetch("CORPUS", "both")

# Posts converted between two clock reads. Keeps the clock out of the
# measurement without making a window overshoot by much.
CHUNK = 50

def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

# Converts the corpus in a loop until DURATION is over, and returns the
# posts/s of every window.
def measure(corpus)
  windows = []
  index = 0
  window_posts = 0
  started = monotonic
  window_started = started

  loop do
    CHUNK.times do
      Markbridge.bbcode_to_markdown(corpus[index])
      index += 1
      index = 0 if index == corpus.size
    end
    window_posts += CHUNK

    now = monotonic
    window_elapsed = now - window_started
    if window_elapsed >= WINDOW
      windows << window_posts / window_elapsed
      window_posts = 0
      window_started = now
    end

    break if now - started >= DURATION
  end

  windows
end

def report(label, corpus)
  kb_per_post = corpus.sum(&:bytesize) / corpus.size / 1024.0
  windows = measure(corpus)

  puts "#{label} (#{corpus.size} posts, #{format("%.1f", kb_per_post)} KB each)"
  windows.each_with_index do |rate, i|
    bar = "#" * (rate / windows.max * 40).round
    puts format("  %3ds %8.0f posts/s  %s", (i + 1) * WINDOW, rate, bar)
  end

  first = windows.first
  steady = windows.last(3).sum / windows.last(3).size
  puts format(
         "  first window %.0f posts/s, steady %.0f posts/s (%+.0f%%), %.1f MB/s steady",
         first,
         steady,
         (steady / first - 1) * 100,
         steady * kb_per_post / 1024,
       )
  puts
end

puts RUBY_DESCRIPTION
puts "duration #{DURATION.round}s per corpus, #{WINDOW.round}s windows, #{POSTS} posts"
puts

report("ascii", Corpus.build(Corpus::WORDS_ASCII, count: POSTS)) if CORPUS != "multi"
report("multibyte", Corpus.build(Corpus::WORDS_MULTI, count: POSTS)) if CORPUS != "ascii"
