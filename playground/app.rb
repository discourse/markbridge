# frozen_string_literal: true

require "json"
require "sinatra/base"

require_relative "../lib/markbridge/all"
require_relative "ast_presenter"
require_relative "cooker"
require_relative "examples"

module Markbridge
  module Playground
    class App < Sinatra::Base
      # The names the UI and the URLs use, and the format Markbridge.convert takes.
      FORMATS = {
        "bbcode" => :bbcode,
        "html" => :html,
        "text_formatter" => :text_formatter_xml,
        "media_wiki" => :mediawiki,
      }.freeze

      # The switches of the UI. The other features of the renderer
      # (details, poll, post_event) have no switch, because no parser
      # builds their nodes.
      DEFAULT_OPTIONS = { "spoiler" => true, "bbcode" => true, "normalize" => true }.freeze

      COOKER = Cooker.new

      set :views, File.join(__dir__, "views")
      set :public_folder, File.join(__dir__)

      post "/convert" do
        content_type :json

        payload = JSON.parse(request.body.read)
        result =
          convert(
            format: payload.fetch("format"),
            input: payload.fetch("input", ""),
            options: payload.fetch("options", {}),
          )
        JSON.generate(result)
      rescue JSON::ParserError => e
        halt 422, JSON.generate(error: "invalid JSON payload: #{e.message}")
      rescue StandardError => e
        # A render error is something the UI shows, with the class, because
        # the class is what a converter would rescue.
        halt 422,
             JSON.generate(error: "#{e.class.name.delete_prefix("Markbridge::")}: #{e.message}")
      end

      # The page is the same for every path, the script reads the example
      # from it (/bbcode/everything).
      get "/?:format?/?:example?" do
        erb :index,
            locals: {
              data_json:
                JSON.generate(
                  examples: Examples.catalog,
                  defaults: DEFAULT_OPTIONS,
                  preview: {
                    engine: COOKER.engine,
                    unavailable: COOKER.unavailable_reason,
                  },
                ),
            }
      end

      private

      def convert(format:, input:, options: {})
        options = DEFAULT_OPTIONS.merge(options.slice(*DEFAULT_OPTIONS.keys))
        features = { spoiler: options["spoiler"] == true, bbcode: options["bbcode"] == true }
        input = input.to_s

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        conversion =
          Markbridge.convert(
            input,
            format: FORMATS.fetch(format) { raise ArgumentError, "unsupported format: #{format}" },
            renderer: renderer_for(features),
            normalize: options["normalize"] == true,
          )
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        presenter = ASTPresenter.new(conversion.ast)
        markdown = conversion.markdown

        {
          format:,
          markdown:,
          ast: presenter.render,
          ast_json: presenter.as_json,
          unknown_tags: unknown_tags(conversion),
          diagnostics: diagnostics(conversion),
          stats: stats(presenter:, markdown:, input:, duration:),
          preview: preview(markdown, features:),
        }
      end

      # The sizes pass as they are: phpBB writes percent, which is what
      # the discourse-bbcode plugin reads.
      def renderer_for(features)
        sizes = ->(size) { size } if features[:bbcode]
        Markbridge.discourse_renderer(features:, sizes:)
      end

      def unknown_tags(conversion)
        conversion
          .unknown_tags
          .map { |name, count| { name: name.to_s, count: } }
          .sort_by { |entry| entry[:name] }
      end

      def diagnostics(conversion)
        diagnostics = conversion.diagnostics

        {
          auto_closed_tags_count: diagnostics.fetch(:auto_closed_tags_count, 0),
          depth_exceeded_count: diagnostics.fetch(:depth_exceeded_count, 0),
          unclosed_raw_tags:
            diagnostics
              .fetch(:unclosed_raw_tags, {})
              .map { |name, count| { name: name.to_s, count: } },
          normalization: diagnostics.fetch(:normalization, []).to_a,
        }
      end

      def stats(presenter:, markdown:, input:, duration:)
        presenter.stats.merge(
          input_chars: input.length,
          markdown_chars: markdown.length,
          duration_ms: (duration * 1000).round(2),
        )
      end

      def preview(markdown, features:)
        cooked = COOKER.cook(markdown, features:)
        return nil unless cooked

        { engine: cooked.engine, html: cooked.html, plugins: cooked.plugins }
      rescue StandardError => e
        { error: e.message }
      end
    end
  end
end
