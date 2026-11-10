# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../playground/app"

RSpec.describe Markbridge::Playground::Examples do
  let(:app) { Markbridge::Playground::App.allocate }

  def node_classes(format)
    input = described_class.everything(format).fetch(:input)
    renderer = Markbridge.discourse_renderer(features: { bbcode: false })
    format = Markbridge::Playground::App::FORMATS.fetch(format)
    ast = Markbridge.convert(input, format:, renderer:, normalize: false).ast
    ast.each_descendant.map(&:class).uniq
  end

  def element_classes(registry)
    registry.filter_map { |_name, handler| handler.element_class }.uniq
  end

  describe ".catalog" do
    it "has examples for every format the playground offers" do
      expect(described_class.catalog.map { |example| example.fetch(:format) }.uniq).to eq(
        Markbridge::Playground::App::FORMATS.keys,
      )
    end

    it "gives every example an id, a title, a description and an input" do
      catalog = described_class.catalog

      expect(catalog).to all(include(:id, :format, :slug, :title, :description, :input))
      expect(catalog).to all(satisfy { |example| !example.fetch(:input).strip.empty? })
      expect(catalog.map { |example| example.fetch(:id) }.uniq.size).to eq(catalog.size)
    end

    it "lists every file in the examples directory" do
      files =
        Dir.glob("*/*", base: described_class::DIRECTORY).map { |file| file.sub(/\.\w+\z/, "") }

      expect(described_class.catalog.map { |example| example.fetch(:id) }).to match_array(files)
    end

    it "starts every format with the example that has everything" do
      firsts =
        described_class.catalog.group_by { |example| example.fetch(:format) }.values.map(&:first)

      expect(firsts.map { |example| example.fetch(:slug) }).to all(eq("everything"))
    end

    it "converts every example with every switch on and off" do
      described_class.catalog.each do |example|
        [true, false].each do |on|
          options = { "spoiler" => on, "bbcode" => on, "normalize" => on }
          result =
            app.send(
              :convert,
              format: example.fetch(:format),
              input: example.fetch(:input),
              options:,
            )

          expect(result.fetch(:markdown)).not_to be_empty, "#{example.fetch(:id)} has no output"
        end
      end
    end
  end

  # A new handler has to show up in the example, so the playground keeps
  # showing all a parser can do.
  describe "the example with everything" do
    it "uses every tag name of the BBCode parser" do
      input = described_class.everything("bbcode").fetch(:input)
      registry = Markbridge::Parsers::BBCode::HandlerRegistry.default

      missing =
        registry.map(&:first).reject { |name| input.match?(/\[#{Regexp.escape(name)}[\]=\s]/i) }

      expect(missing).to be_empty, "missing in everything.bbcode: #{missing.join(", ")}"
      expect(node_classes("bbcode")).to include(*element_classes(registry))
    end

    it "uses every element name of the HTML parser" do
      input = described_class.everything("html").fetch(:input)
      registry = Markbridge::Parsers::HTML::HandlerRegistry.default

      missing = registry.map(&:first).reject { |name| input.match?(/<#{name}[\s>]/i) }

      expect(missing).to be_empty, "missing in everything.html: #{missing.join(", ")}"
      expect(node_classes("html")).to include(*element_classes(registry))
    end

    it "uses every element name of the TextFormatter parser" do
      input = described_class.everything("text_formatter").fetch(:input)
      registry = Markbridge::Parsers::TextFormatter::HandlerRegistry.default

      missing = registry.map(&:first).reject { |name| input.match?(%r{<#{name}[\s>/]}) }

      expect(missing).to be_empty, "missing in everything.xml: #{missing.join(", ")}"
      expect(node_classes("text_formatter")).to include(*element_classes(registry))
    end

    it "uses every inline tag and every block of the MediaWiki parser" do
      input = described_class.everything("media_wiki").fetch(:input)
      registry = Markbridge::Parsers::MediaWiki::InlineTagRegistry.default
      # What the wikitext syntax itself builds, next to the inline tags.
      blocks = [
        Markbridge::AST::Bold,
        Markbridge::AST::Italic,
        Markbridge::AST::Url,
        Markbridge::AST::Heading,
        Markbridge::AST::List,
        Markbridge::AST::ListItem,
        Markbridge::AST::HorizontalRule,
        Markbridge::AST::Code,
        Markbridge::AST::Table,
        Markbridge::AST::TableRow,
        Markbridge::AST::TableCell,
      ]

      missing = registry.map(&:first).reject { |name| input.match?(%r{<#{name}[\s>/]}i) }

      expect(missing).to be_empty, "missing in everything.wiki: #{missing.join(", ")}"
      expect(node_classes("media_wiki")).to include(
        *registry.filter_map { |_name, entry| entry.element_class },
        *blocks,
      )
      expect(input.scan(/^(=+) /).flatten.map(&:length).uniq.sort).to eq((1..6).to_a)
    end
  end
end
