#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Custom Attachment Renderer
#
# This example demonstrates how to create a custom attachment renderer that maps
# attachment IDs/indices to actual upload URLs for your specific forum platform.
#
# The default AttachmentTag is intentionally a STUB that outputs HTML comments.
# You should replace it with your own implementation that knows how to look up
# and generate the correct URLs for your attachments.

require "bundler/setup"
require "markbridge/bbcode"

# Example 1: Simple ID-based attachment lookup
# Assumes you have a method to look up attachment URLs by ID
class SimpleAttachmentTag < Markbridge::Renderers::Discourse::Tags::AttachmentTag
  def initialize(attachment_url_map = {})
    @attachment_url_map = attachment_url_map
  end

  def render(element, _interface)
    # Look up URL by ID or index
    url = lookup_url(element)
    alt = element.alt || element.filename || ""

    # Render as standard Markdown image
    "![#{alt}](#{url})"
  end

  private

  def lookup_url(element)
    key = element.id || element.index
    @attachment_url_map[key] || "missing-attachment://#{key}"
  end
end

# Example 2: Database-backed attachment lookup
# For production use, you'd query your database
class DatabaseAttachmentTag < Markbridge::Renderers::Discourse::Tags::AttachmentTag
  def initialize(attachment_repository)
    @repository = attachment_repository
  end

  def render(element, _interface)
    attachment = find_attachment(element)
    return "<!-- MISSING ATTACHMENT -->" unless attachment

    alt = element.alt || element.filename || attachment[:filename] || ""
    "![#{alt}](#{attachment[:url]})"
  end

  private

  def find_attachment(element)
    if element.id
      @repository.find_by_id(element.id)
    elsif element.index
      @repository.find_by_index(element.index)
    end
  end
end

# Example 3: Context-aware attachment lookup (phpBB style)
# phpBB attachments are post-relative, so you need post context
class ContextAwareAttachmentTag < Markbridge::Renderers::Discourse::Tags::AttachmentTag
  def initialize(post_id:, attachment_repository:)
    @post_id = post_id
    @repository = attachment_repository
  end

  def render(element, _interface)
    if element.id
      # Absolute ID (vBulletin/XenForo)
      attachment = @repository.find_by_id(element.id)
    elsif element.index
      # Post-relative index (phpBB)
      attachment = @repository.find_by_post_and_index(@post_id, element.index)
    end

    return "<!-- MISSING ATTACHMENT -->" unless attachment

    alt = element.alt || element.filename || attachment[:filename] || ""
    "![#{alt}](#{attachment[:url]})"
  end
end

# Usage example with a custom tag
puts "=" * 80
puts "Example: Custom Attachment Renderer"
puts "=" * 80

# Mock attachment URL map (in production, this would be from your database)
attachment_urls = {
  "1234" => "https://example.com/uploads/image1.jpg",
  "5678" => "https://example.com/uploads/diagram.png",
  "0" => "https://example.com/uploads/screenshot.png",
}

# Create custom tag library with our custom attachment tag
library = Markbridge::Renderers::Discourse::TagLibrary.default
library.register(Markbridge::AST::Attachment, SimpleAttachmentTag.new(attachment_urls))

# Create renderer with custom library
renderer = Markbridge::Renderers::Discourse::Renderer.new(tag_library: library)

# Test various attachment formats
test_cases = [
  "[attach]1234[/attach]",
  "[attachment=0]screenshot.png[/attachment]",
  '[attach alt="diagram"]5678[/attach]',
  "[attach]9999[/attach]", # Missing attachment
]

parser = Markbridge::Parsers::BBCode::Parser.new

test_cases.each do |bbcode|
  puts "\nBBCode:  #{bbcode}"
  ast = parser.parse(bbcode)
  markdown = renderer.render(ast)
  puts "Result:  #{markdown}"
end

puts "\n" + "=" * 80
puts "Note: The default renderer outputs HTML comments. Override with your own!"
puts "=" * 80
