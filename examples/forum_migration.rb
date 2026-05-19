#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Forum migration to Discourse
#
# This is the canonical end-to-end example for the Markbridge migration
# API. It exercises every feature an importer cares about:
#
#   - Custom AST node + BBCode handler ([font])
#   - Handler delegation via `overlay` (custom <a>-style URL handler
#     wrapping the default)
#   - `Markbridge.discourse_renderer(...)` factory
#   - `tags:` Hash, `unregister:` Array, `allow: :lists` for selective
#     escaper passthrough
#   - The AST-mutation block on `Markbridge.convert` (append orphan
#     attachments before rendering)
#   - `Conversion#errors` / `Conversion#unknown_tags`
#   - `raise_on_error: false` for per-row failure isolation
#   - `Markbridge.convert(input, format:)` dispatch
#
# Note: this example deliberately keeps the converter side trivial.
# Real importers put placeholder resolution (uploads, mentions,
# internal links) in custom handler subclasses at parse time, with
# the AST node carrying the resolved identifier — render Tags then
# stay one-line output formatters. That layer lives in the
# converter framework, not Markbridge.
#
# Run it:  bundle exec ruby examples/forum_migration.rb

require "bundler/setup"
require "markbridge/all"

# -- Custom AST + handler ----------------------------------------------------

# AST node for [font=courier]...[/font] BBCode tags.
class FontNode < Markbridge::AST::Element
  attr_reader :font

  def initialize(font: nil)
    super()
    @font = font
  end
end

# Parser handler. BBCode handlers are class-based (not lambda-based)
# because the open/close lifecycle and auto_closeable? introspection
# don't fit a single lambda shape.
class FontHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
  def initialize
    @element_class = FontNode
  end

  def on_open(token:, context:, registry:, tokens: nil)
    font = token.attrs[:font] || token.attrs[:option]
    context.push(FontNode.new(font:), token:)
  end

  def auto_closeable?
    true
  end

  attr_reader :element_class
end

# Renderer Tag: monospace fonts → inline code, everything else falls
# through to the children (no marker).
FONT_TAG =
  Markbridge::Renderers::Discourse::Tag.new do |element, interface|
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)

    if element.font&.match?(/\b(courier|monospace|consolas|menlo|monaco)\b/i)
      "`#{content.strip}`"
    else
      content
    end
  end

# -- Build the importer's reusable parts (handlers + renderer) --------------
#
# Forum posts using "1. item" / "- item" syntax need their leading
# markers preserved (the default escaper would escape them as
# `\- item`). Pass `allow: :lists` to the renderer factory — no
# subclassing required.

class LoggingUrlHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
  def initialize(default:)
    @default = default
    @element_class = default.element_class
  end

  def on_open(token:, context:, registry:, tokens: nil)
    # ...real importer would log here; we just delegate.
    @default.on_open(token:, context:, registry:, tokens:)
  end

  attr_reader :element_class
end

HANDLERS =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |r|
    r.register("font", FontHandler.new)

    # Demo of overlay/delegation: wrap the default URL handler once
    # and re-bind it under every tag name that should use it. Note:
    # when multiple tag names share an element class (url/link/iurl
    # all build AST::Url), the wrapper must be a *single* instance
    # so the closing-strategy's element→handler reconciliation
    # finds the same object on both sides. `overlay` with one name
    # is the simple case; multi-name aliases need the explicit
    # `register` form below.
    default_url = r["url"]
    r.register(%w[url link iurl], LoggingUrlHandler.new(default: default_url))
  end

RENDERER =
  Markbridge.discourse_renderer(
    tags: {
      FontNode => FONT_TAG,
    },
    # Drop built-ins so they fall through to render_children. Forum
    # posts often use [color]/[size]/[u] decoratively; importers
    # typically don't want those bytes in the migrated Markdown.
    unregister: [Markbridge::AST::Color, Markbridge::AST::Size, Markbridge::AST::Underline],
    allow: :lists,
  )

# -- Sample posts to migrate ------------------------------------------------

POSTS = [
  {
    id: 1,
    format: :bbcode,
    body: "[b]hello[/b] [color=red]world[/color] [font=courier]code[/font]",
  },
  {
    id: 2,
    format: :bbcode,
    body:
      "see [url=https://forum.example.com/t/42]this[/url] and [url=https://example.org]ext[/url]",
  },
  { id: 3, format: :bbcode, body: "[unknownext]hello[/unknownext]" },
  {
    id: 4,
    format: :html,
    body: "<b>html</b> <a href='https://forum.example.com/u/alice'>alice</a>",
  },
  {
    id: 5,
    format: :bbcode,
    body: "[b]see attachments below[/b]",
    orphan_attachments: %w[5001 5002],
  },
]

# -- The migration loop ------------------------------------------------------

stats = { ok: 0, errors: 0 }

POSTS.each do |post|
  # `Markbridge.convert(..., format:, &block)` yields the parsed AST
  # between parse and render, so we can append attachments that
  # weren't in the source post but should appear at the bottom of the
  # rendered Markdown.
  result =
    Markbridge.convert(
      post[:body],
      format: post[:format],
      handlers: post[:format] == :bbcode ? HANDLERS : nil,
      renderer: RENDERER,
      raise_on_error: false,
    ) do |ast|
      Array(post[:orphan_attachments]).each do |att|
        ast << Markbridge::AST::Text.new("\n\n[attachment:#{att}]")
      end
    end

  if result.errors.any?
    stats[:errors] += 1
    puts "post ##{post[:id]} FAILED: #{result.errors.first.message}"
    next
  end

  stats[:ok] += 1
  puts "post ##{post[:id]} (#{post[:format]}): #{result.markdown.inspect}"
  puts "  unknown_tags: #{result.unknown_tags}" if result.unknown_tags.any?
end

puts
puts "Migration complete:"
puts "  ok: #{stats[:ok]}"
puts "  errors: #{stats[:errors]}"

# -- Phase 2: HTML pre-processing + AST transform --------------------------
#
# The forum-import use case for the three follow-up features:
#
#   1. Pre-parsed Nokogiri input — parse the HTML once with Nokogiri,
#      run any structural pre-passes (DOM mutation, classification
#      tags), then hand the live fragment to Markbridge. No serialize
#      → re-parse round-trip in between.
#
#   2. AST traversal helpers — `each_descendant`, `descendants(klass)`,
#      `replace_child(old, new)`. Used here to find trailing paragraphs
#      and wrap them in a Details block.
#
#   3. AST::Details — the lifted collapsible-block node. Renders to
#      `[details="title"]…[/details]` in normal Markdown and to
#      `<details><summary>…</summary>…</details>` inside an HTML block.
#
# The "signature collapser" below is a stripped-down version of the
# wrapper that downstream email-migration importers carry today.

puts
puts "Phase 2: HTML pre-processing + AST transform"
puts "============================================"

HTML_POSTS = [{ id: 100, body: <<~HTML }, { id: 101, body: <<~HTML }]
      <p>Hello team,</p>
      <p>The deploy passed. Shipping it.</p>
      <p>--<br>Alex Doe<br>Engineering</p>
    HTML
      <p>Reminder: the all-hands is Friday at 3pm.</p>
      <p>RSVP via the calendar invite.</p>
    HTML

# AST-level signature collapser. Walks the trailing Paragraph children
# of the Document; if a paragraph starts with "--" (the email-sigdash
# convention), wrap it and everything below it in AST::Details.
def collapse_signature!(ast)
  paragraphs = ast.children.select { |c| c.is_a?(Markbridge::AST::Paragraph) }
  first_sig =
    paragraphs.find do |para|
      text = para.descendants(Markbridge::AST::Text).map(&:text).join
      text.start_with?("--")
    end
  return unless first_sig

  details = Markbridge::AST::Details.new(title: "Signature")
  start = ast.children.index(first_sig)
  ast.children[start..].each { |child| details << child }
  ast.children.slice!(start..)
  ast << details
end

HTML_POSTS.each do |post|
  # The two-step we couldn't do before: parse once with Nokogiri, then
  # hand the fragment directly to Markbridge — no re-parse, no
  # serialize, no URL-percent-encoding side effect.
  fragment = Nokogiri::HTML.fragment(post[:body])

  result =
    Markbridge.html_to_markdown(fragment, renderer: RENDERER) { |ast| collapse_signature!(ast) }

  puts "post ##{post[:id]}:"
  puts result.markdown.lines.map { |line| "  #{line}" }.join
  puts
end
