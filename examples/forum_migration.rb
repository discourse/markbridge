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
#   - Custom Tags emitting side data via `interface.emit`
#   - `Markbridge.discourse_renderer(...)` factory
#   - `tags:` Hash, `unregister:` Array, custom escaper (subclass of
#     MarkdownEscaper), custom postprocessor
#   - `Conversion#emissions` / `Conversion#errors` / `Conversion#unknown_tags`
#   - `raise_on_error: false` for per-row failure isolation
#   - `Markbridge.convert(input, format:)` dispatch
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

# -- Custom URL Tag emitting placeholder records ----------------------------

# Real importers swap [url=…] payloads for placeholders that get
# resolved later (after the destination posts have IDs). The Tag
# emits a side-channel record so the importer can pick it up after
# rendering — no mutable hash injected into the Tag constructor.
class PlaceholderUrlTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    href = element.href
    text = interface.render_children(element, context: interface.with_parent(element))

    if internal_link?(href)
      placeholder = "[[link:#{next_id}]]"
      interface.emit(:link, { url: href, text:, placeholder: })
      placeholder
    else
      "[#{text}](#{href})"
    end
  end

  private

  def internal_link?(href)
    href&.start_with?("https://forum.example.com/")
  end

  def next_id
    @counter ||= 0
    @counter += 1
  end
end

# -- Custom escaper that allows list markers through -------------------------
#
# Markdown forum posts using "1. item" / "- item" syntax need their
# leading markers preserved when rendered (the default escaper would
# escape them). This is the Liferay/Wolfram pattern.
class ListPermissiveEscaper < Markbridge::Renderers::Discourse::MarkdownEscaper
  private

  def escape_block_level(content, prev_was_paragraph)
    case content.getbyte(0)
    when 0x2D, 0x2A, 0x2B # '-', '*', '+'
      return content, false if content.match?(/\A[-*+]\s/)
    when 0x30..0x39
      return content, false if content.match?(/\A\d+[.)]\s/)
    end
    super
  end
end

# -- Build the importer's reusable parts (handlers + renderer) --------------

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
      Markbridge::AST::Url => PlaceholderUrlTag.new,
      FontNode => FONT_TAG,
    },
    # Drop built-ins so they fall through to render_children. Forum
    # posts often use [color]/[size]/[u] decoratively; importers
    # typically don't want those bytes in the migrated Markdown.
    unregister: [Markbridge::AST::Color, Markbridge::AST::Size, Markbridge::AST::Underline],
    escaper: ListPermissiveEscaper.new,
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
    body: "see [url=https://forum.example.com/t/42]this[/url] and [url=https://example.org]ext[/url]",
  },
  {
    id: 3,
    format: :bbcode,
    body: "[unknownext]hello[/unknownext]",
  },
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
emitted_links = []

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
  emitted_links.concat(result.emitted(:link))

  puts "post ##{post[:id]} (#{post[:format]}): #{result.markdown.inspect}"
  puts "  unknown_tags: #{result.unknown_tags}" if result.unknown_tags.any?
end

puts
puts "Migration complete:"
puts "  ok: #{stats[:ok]}"
puts "  errors: #{stats[:errors]}"
puts "  link placeholders emitted: #{emitted_links.size}"
emitted_links.each { |l| puts "    #{l[:placeholder]} -> #{l[:url]}" }
