# frozen_string_literal: true

require_relative "../spec/support/line_process"

module Markbridge
  module Playground
    # Cooks Markdown to HTML for the preview, with the same Node scripts
    # the specs cook with: Discourse's own engine when `bin/discourse-engine`
    # has built it, plain markdown-it otherwise. Without Node or
    # markdown-it there is no preview, and +unavailable_reason+ says why.
    #
    # One Node process per set of plugins, started with the first cook.
    class Cooker
      ROOT = File.expand_path("..", __dir__)
      ENGINE = File.join(ROOT, "tmp", "discourse_engine")
      ENGINE_SCRIPT = File.join(ROOT, "spec", "support", "discourse_engine", "cook.mjs")
      MARKDOWN_IT = File.join(ROOT, "spec", "support", "markdown_it")
      MARKDOWN_IT_SCRIPT = File.join(MARKDOWN_IT, "cook.mjs")

      # The plugins a stock Discourse loads in any case. No parser builds
      # a poll or a details block, so the playground has no switch for them.
      STOCK_PLUGINS = %w[discourse-details poll].freeze
      FEATURE_PLUGINS = { spoiler: "spoiler-alert", bbcode: "discourse-bbcode" }.freeze

      Cooked = Data.define(:engine, :html, :plugins)

      def initialize
        @lock = Mutex.new
        @processes = {}
      end

      # @return [Symbol, nil] :discourse, :markdown_it or nil
      def engine
        return nil unless node?
        return :discourse if File.file?(File.join(ENGINE, "engine.json"))

        :markdown_it if File.directory?(File.join(MARKDOWN_IT, "node_modules", "markdown-it"))
      end

      # @return [String, nil] what is missing for a preview
      def unavailable_reason
        return nil if engine
        return "Node is not on the PATH." unless node?

        "markdown-it is not installed. Run `npm ci --prefix spec/support/markdown_it`, " \
          "or `bin/discourse-engine` for Discourse's own engine."
      end

      # @param markdown [String]
      # @param features [Hash{Symbol => Boolean}] the plugins of the site
      # @return [Cooked, nil] nil when there is no engine
      def cook(markdown, features:)
        case engine
        when :discourse
          plugins = plugins_for(features)
          command = [ENGINE_SCRIPT, "--engine", ENGINE, "--plugins", plugins.join(",")]
          Cooked.new(engine: :discourse, html: cook_with(command, markdown), plugins:)
        when :markdown_it
          html = cook_with([MARKDOWN_IT_SCRIPT], markdown)
          Cooked.new(engine: :markdown_it, html:, plugins: [])
        end
      end

      private

      def node?
        LineProcess.program?("node")
      end

      def plugins_for(features)
        STOCK_PLUGINS + FEATURE_PLUGINS.filter_map { |feature, plugin| plugin if features[feature] }
      end

      def cook_with(command, markdown)
        process = @lock.synchronize { @processes[command] ||= LineProcess.new("node", *command) }
        process.ask(markdown:).fetch("html")
      end
    end
  end
end
