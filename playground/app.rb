# frozen_string_literal: true

require "json"
require "sinatra/base"

require_relative "../lib/markbridge/all"
require_relative "ast_presenter"
require_relative "examples"

module Markbridge
  module Playground
    class App < Sinatra::Base
      set :views, File.join(__dir__, "views")
      set :public_folder, File.join(__dir__)

      get "/convert.:format" do
        # Prevent Sinatra from matching /convert as a format route
        pass
      end

      post "/convert" do
        content_type :json

        payload = JSON.parse(request.body.read)
        result = convert(format: payload.fetch("format"), input: payload.fetch("input", ""))
        JSON.generate(result)
      rescue KeyError, ArgumentError => e
        halt 422, JSON.generate(error: e.message)
      rescue JSON::ParserError => e
        halt 422, JSON.generate(error: "invalid JSON payload: #{e.message}")
      end

      get "/?:format?/?:scenario?" do
        examples = Examples.catalog
        initial_example = find_example(examples) || examples.first
        initial_result =
          convert(format: initial_example.fetch(:format), input: initial_example.fetch(:input))

        erb :index,
            locals: {
              examples_json: JSON.generate(examples),
              initial_example_id: initial_example.fetch(:id),
              initial_result_json: JSON.generate(initial_result),
            }
      end

      private

      def find_example(examples)
        return nil unless params[:format]

        format = params[:format].tr("-", "_")
        if params[:scenario]
          scenario = params[:scenario].tr("-", "_")
          examples.find { |e| e[:format] == format && e[:scenario] == scenario }
        else
          examples.find { |e| e[:format] == format }
        end
      end

      def convert(format:, input:)
        parser = parser_for(format)
        ast = parser.parse(input.to_s)
        renderer = Markbridge::Renderers::Discourse::Renderer.new
        presenter = ASTPresenter.new(ast)
        markdown = cleanup_markdown(renderer.render(ast))
        unknown_tags = normalize_unknown_tags(parser)

        {
          format:,
          markdown:,
          ast: presenter.render,
          ast_json: presenter.as_json,
          unknown_tags:,
          diagnostics: parser_diagnostics(parser),
          stats: build_stats(presenter:, markdown:, input:, unknown_tags:),
        }
      end

      def parser_for(format)
        case format
        when "bbcode"
          Markbridge::Parsers::BBCode::Parser.new
        when "html"
          Markbridge::Parsers::HTML::Parser.new
        when "text_formatter"
          Markbridge::Parsers::TextFormatter::Parser.new
        when "media_wiki"
          Markbridge::Parsers::MediaWiki::Parser.new
        else
          raise ArgumentError, "unsupported format: #{format.inspect}"
        end
      end

      def cleanup_markdown(text)
        text.gsub(/\n{3,}/, "\n\n").gsub(/^[ \t]+$/m, "").strip
      end

      def normalize_unknown_tags(parser)
        return [] unless parser.respond_to?(:unknown_tags)

        parser
          .unknown_tags
          .map { |name, count| { name: name.to_s, count: } }
          .sort_by { |entry| entry[:name] }
      end

      def build_stats(presenter:, markdown:, input:, unknown_tags:)
        presenter.stats.merge(
          input_lines: line_count(input),
          input_chars: input.length,
          markdown_lines: line_count(markdown),
          markdown_chars: markdown.length,
          unknown_tag_total: unknown_tags.sum { |entry| entry[:count] },
        )
      end

      def parser_diagnostics(parser)
        diagnostics = {}

        diagnostics[:auto_closed_tags_count] = parser.auto_closed_tags_count if parser.respond_to?(
          :auto_closed_tags_count,
        )
        diagnostics[:depth_exceeded_count] = parser.depth_exceeded_count if parser.respond_to?(
          :depth_exceeded_count,
        )

        if parser.respond_to?(:unclosed_raw_tags)
          diagnostics[:unclosed_raw_tags] = Array(parser.unclosed_raw_tags).map(&:to_s).sort
        end

        diagnostics
      end

      def line_count(text)
        return 0 if text.empty?

        text.count("\n") + 1
      end
    end
  end
end
