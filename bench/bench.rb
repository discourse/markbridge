# frozen_string_literal: true

# Benchmark suite for Markbridge end-to-end conversion paths.
#
# Two modes:
#
#   bundle exec ruby --yjit bench/bench.rb            # suite mode
#   bundle exec ruby --yjit bench/bench.rb --isolated # one process per report
#
# Suite mode runs all reports in one process. It's faster to run
# but YJIT compiles 12 hot paths concurrently, so they compete for
# the JIT budget and inline-decision heuristics — the resulting
# numbers tend to under-report per-path throughput, especially on
# the inline-escape path.
#
# Isolated mode forks a fresh process per report. Each path gets
# YJIT all to itself, so numbers are closer to what a hot path in
# a real workload would see. Use this when comparing branch-to-
# branch on a single path.
#
# Reproducibility:
# - --yjit is essential; non-YJIT numbers are 2-5x slower and
#   don't reflect production.
# - benchmark-ips warmup is 2s / measure 3s. Shorter warmup
#   under-reports YJIT-friendly code.

REPORTS = {
  "simple" => {
    type: :convert,
    input: "[b]bold[/b] [i]italic[/i] [u]underline[/u] text",
  },
  "nested" => {
    type: :convert,
    input: "[b]bold [i]italic [u]underline[/u][/i][/b]",
  },
  "list" => {
    type: :convert,
    input: <<~BBCODE,
      [list]
      [*]First item
      [*]Second item
      [*]Third item
      [/list]
    BBCODE
  },
  "table" => {
    type: :convert,
    input: <<~BBCODE,
      [table]
      [tr][th]A[/th][th]B[/th][th]C[/th][/tr]
      [tr][td]1[/td][td]2[/td][td]3[/td][/tr]
      [tr][td]4[/td][td]5[/td][td]6[/td][/tr]
      [/table]
    BBCODE
  },
  "quote_nested" => {
    type: :convert,
    input: <<~BBCODE,
      [quote="alice"]
      Some quoted text with [b]bold[/b] content.
      [quote="bob"]
      Nested quote.
      [/quote]
      [/quote]
    BBCODE
  },
  "code" => {
    type: :convert,
    input: "[code]def hello\n  puts 'hello world'\nend[/code]",
  },
  "url" => {
    type: :convert,
    input:
      "Check out [url=https://example.com]this link[/url] and [url=https://foo.com]another[/url]",
  },
  "escaping" => {
    type: :convert,
    input:
      "Text with *asterisks* and _underscores_ and `backticks` and [brackets] and |pipes|" \
        "\n\n# Not a heading\n---\nnot a rule",
  },
  "mixed" => {
    type: :convert,
    input: [
      "[b]bold[/b]",
      "[quote]x[/quote]",
      "[list]\n[*]a\n[*]b\n[/list]",
      "[table][tr][td]1[/td][td]2[/td][/tr][/table]",
      "[code]x[/code]",
    ].join("\n\n"),
  },
  "large_doc" => {
    type: :convert,
    input:
      (
        [
          "[b]bold[/b]",
          "[quote]x[/quote]",
          "[list]\n[*]a\n[*]b\n[/list]",
          "[table][tr][td]1[/td][td]2[/td][/tr][/table]",
          "[code]x[/code]",
        ].join("\n\n") + "\n\n"
      ) * 20,
  },
  "escape_plain" => {
    type: :escape,
    input: "This is plain text with no special chars. " * 100,
  },
  "escape_mixed" => {
    type: :escape,
    input: "Text with *stars*, _underscores_, `code`, and [brackets]. " * 50,
  },
}

# Defaults match a CRuby+YJIT warmup curve. Override with env vars
# for slow-warmup engines (JRuby/TruffleRuby) or for higher-fidelity
# measurements.
WARMUP = Integer(ENV.fetch("BENCH_WARMUP", "2"))
MEASURE = Integer(ENV.fetch("BENCH_MEASURE", "3"))

def all_in_one_process(report_names)
  $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
  require "markbridge/all"
  require "benchmark/ips"

  escaper = Markbridge::Renderers::Discourse::MarkdownEscaper.new

  Benchmark.ips do |x|
    x.config(time: MEASURE, warmup: WARMUP)
    report_names.each do |name|
      report = REPORTS.fetch(name)
      input = report[:input]
      case report[:type]
      when :convert
        x.report(name) { Markbridge.bbcode_to_markdown(input) }
      when :escape
        x.report(name) { escaper.escape(input) }
      end
    end
  end
end

def isolated(report_names)
  ruby_args = RUBY_ENGINE == "ruby" ? ["--yjit"] : []
  report_names.each do |name|
    cmd = [RbConfig.ruby, *ruby_args, __FILE__, "--single", name]
    pid = Process.spawn(*cmd)
    Process.wait(pid)
  end
end

def single_report(name)
  $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
  require "markbridge/all"
  require "benchmark/ips"

  report = REPORTS.fetch(name)
  input = report[:input]
  escaper = Markbridge::Renderers::Discourse::MarkdownEscaper.new

  Benchmark.ips do |x|
    x.config(time: MEASURE, warmup: WARMUP)
    case report[:type]
    when :convert
      x.report(name) { Markbridge.bbcode_to_markdown(input) }
    when :escape
      x.report(name) { escaper.escape(input) }
    end
  end
end

if ARGV.include?("--single")
  single_report(ARGV[ARGV.index("--single") + 1])
elsif ARGV.include?("--isolated")
  isolated(REPORTS.keys)
else
  all_in_one_process(REPORTS.keys)
end
