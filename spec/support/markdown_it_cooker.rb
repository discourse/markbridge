# frozen_string_literal: true

require "json"
require "nokogiri"
require_relative "line_process"

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

  def self.missing
    if !LineProcess.program?("node")
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

  # Plain markdown-it reads no BBCode: what the renderer writes for a
  # plugin, or for Discourse core's `[u]`, is text to it. See
  # DiscourseEngineCooker#cooks? for the other answer.
  #
  # @param _feature [Symbol]
  # @return [false]
  def self.cooks?(_feature)
    false
  end

  @process = nil

  # @param markdown [String]
  # @return [String] the HTML that markdown-it cooks from +markdown+
  def self.cook(markdown)
    process.ask(markdown:).fetch("html")
  end

  def self.process
    @process ||=
      begin
        reason = missing
        raise "markdown-it cooker: #{reason}" if reason

        LineProcess.new("node", SCRIPT)
      end
  end

  private_class_method :process
end
