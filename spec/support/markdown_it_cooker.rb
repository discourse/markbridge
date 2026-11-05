# frozen_string_literal: true

require "json"
require "nokogiri"
require "open3"

# Cooks Markdown with markdown-it, set up like Discourse (see
# spec/support/markdown_it/cook.mjs).
#
# One Node process cooks everything for a whole spec run. It starts with the
# first cook and ends when Ruby exits. Node is a subprocess and not a gem, so
# this works on JRuby and TruffleRuby too.
#
# Guard example groups with +MarkdownItCooker::SKIP_REASON+. With
# MARKDOWN_IT_REQUIRED=1 (CI sets it) a missing Node or markdown-it fails
# the examples instead of skipping them. The specs read the cooked HTML with
# Nokogiri::HTML5, which JRuby's Nokogiri does not have, so JRuby skips
# them in any case.
module MarkdownItCooker
  DIRECTORY = File.expand_path("markdown_it", __dir__)
  SCRIPT = File.join(DIRECTORY, "cook.mjs")
  SETUP = "npm ci --prefix spec/support/markdown_it"

  def self.node?
    ENV
      .fetch("PATH", "")
      .split(File::PATH_SEPARATOR)
      .any? { |dir| File.executable?(File.join(dir, "node")) }
  end

  def self.missing
    if !node?
      "node is not on the PATH"
    elsif !File.directory?(File.join(DIRECTORY, "node_modules", "markdown-it"))
      "markdown-it is not installed, run `#{SETUP}`"
    end
  end

  REQUIRED = ENV["MARKDOWN_IT_REQUIRED"] == "1"
  # The typographer turns straight quotes into these curly ones, in
  # the same order.
  CURLY_QUOTES = "\u201C\u201D\u2018\u2019"
  STRAIGHT_QUOTES = "\"\"''"

  SKIP_REASON =
    if !defined?(Nokogiri::HTML5)
      "Nokogiri::HTML5 not available on #{RUBY_ENGINE}"
    elsif !REQUIRED
      missing
    end

  @process = nil
  @next_id = 0

  # @param markdown [String]
  # @return [String] the HTML that markdown-it cooks from +markdown+
  def self.cook(markdown)
    stdin, stdout = process
    id = (@next_id += 1)

    stdin.puts(JSON.generate(id:, markdown:))
    line = stdout.gets or raise "cook.mjs stopped without an answer for #{markdown.inspect}"
    answer = JSON.parse(line)
    raise "cook.mjs answered request #{answer["id"]}, expected #{id}" unless answer["id"] == id

    answer["html"]
  end

  def self.process
    @process ||= start
  end

  def self.start
    reason = missing
    raise "markdown-it cooker: #{reason}" if reason

    stdin, stdout, thread = Open3.popen2("node", SCRIPT)
    stdin.set_encoding(Encoding::UTF_8)
    stdout.set_encoding(Encoding::UTF_8)
    stdin.sync = true
    at_exit do
      stdin.close
      thread.join
    end

    [stdin, stdout]
  end

  private_class_method :process, :start, :node?
end
