# frozen_string_literal: true

# Structural enforcement of the html_mode contract documented on
# `Markbridge::Renderers::Discourse::Tag#render`.
#
# Inside an HTML block CommonMark passes content through as raw HTML
# and only re-enters Markdown parsing across blank lines (spec §4.6).
# Every registered tag must therefore render in html_mode as either:
#
#   - a raw HTML fragment (verbatim splice into the surrounding block), or
#   - a `\n\n…\n\n` wrap (deliberate Markdown island; the blank lines
#     close the HTML block, CommonMark parses the inner Markdown, and
#     the next blank line re-opens the block).
#
# Plain text without Markdown sigils is also fine (no parsing surface).
# This spec catches the regression where a new tag emits Markdown into
# an HTML block — the Markdown would render literally rather than being
# interpreted.
#
# It runs through the shared example that ships in `markbridge/rspec`,
# so consumers' custom tags go through exactly this check.
require "markbridge/rspec"

RSpec.describe "html_mode rendering contract" do
  let(:library) { Markbridge::Renderers::Discourse::TagLibrary.default }

  ELEMENT_FACTORIES = {
    Markbridge::AST::Heading => -> { Markbridge::AST::Heading.new(level: 1) },
    Markbridge::AST::Url => -> { Markbridge::AST::Url.new(href: "https://example.com") },
    Markbridge::AST::Email => -> { Markbridge::AST::Email.new(address: "user@example.com") },
    Markbridge::AST::Image => -> { Markbridge::AST::Image.new(src: "https://example.com/x.png") },
    Markbridge::AST::List => -> { Markbridge::AST::List.new(ordered: false) },
    Markbridge::AST::Color => -> { Markbridge::AST::Color.new(color: "red") },
    Markbridge::AST::Size => -> { Markbridge::AST::Size.new(size: 14) },
    Markbridge::AST::Align => -> { Markbridge::AST::Align.new(alignment: "center") },
    Markbridge::AST::Mention => -> { Markbridge::AST::Mention.new(name: "alice") },
    Markbridge::AST::Attachment => -> { Markbridge::AST::Attachment.new(id: "1") },
    Markbridge::AST::Upload => -> do
      Markbridge::AST::Upload.new(sha1: "abc", filename: "pic.png", type: :image)
    end,
    Markbridge::AST::Event => -> do
      Markbridge::AST::Event.new(name: "demo", starts_at: "2026-01-01")
    end,
    Markbridge::AST::Poll => -> { Markbridge::AST::Poll.new(options: %w[a b]) },
  }.freeze

  def build_element(element_class)
    element = ELEMENT_FACTORIES.fetch(element_class) { -> { element_class.new } }.call
    if element.is_a?(Markbridge::AST::Element) && element.children.empty?
      element << Markbridge::AST::Text.new("x")
    end
    element
  end

  Markbridge::Renderers::Discourse::Tags.constants.each do |tag_constant|
    element_class = Markbridge::Renderers::Discourse::TagLibrary.default.ast_class_for(tag_constant)
    next unless element_class

    describe tag_constant.to_s do
      it_behaves_like "an html_mode safe tag" do
        let(:tag) { library[element_class] }
        let(:element) { build_element(element_class) }
      end
    end
  end
end
