# frozen_string_literal: true

require "json"
require "nokogiri"
require_relative "cook_process"

# Cooks Markdown with Discourse's own engine: the pretty-text bundle of a
# Discourse checkout, with the bundled plugins and discourse-bbcode (see
# spec/support/discourse_engine/cook.mjs). `bin/discourse-engine` builds it
# into tmp/discourse_engine, which takes network and a few minutes, so the
# examples that cook with it skip when it is not there and the nightly
# workflow runs them with DISCOURSE_ENGINE_REQUIRED=1.
#
# The engine cooks per profile: which plugins are loaded and which site
# settings are on. One Node process serves each profile for the whole spec
# run. +renderer+ gives the renderer whose features match a profile, so a
# spec writes the Markdown for the site it cooks on.
#
# Tag an example group with +:discourse_engine+. spec_helper leaves those
# examples out when +SKIP_REASON+ says why they cannot run. The specs read
# the cooked HTML with Nokogiri::HTML5, which JRuby's Nokogiri does not
# have, so JRuby leaves them out in any case.
module DiscourseEngineCooker
  DIRECTORY = File.expand_path("discourse_engine", __dir__)
  SCRIPT = File.join(DIRECTORY, "cook.mjs")
  ENGINE = File.expand_path("../../tmp/discourse_engine", __dir__)
  SETUP = "bin/discourse-engine"

  IDENTITY = ->(value) { value }

  # The plugins and settings of three target sites, with the renderer
  # features that fit them. Discourse loads the markdown features of a
  # plugin only when the plugin is on, so a profile names the plugins
  # that are on. A stock install has details, spoiler-alert and poll on
  # and discourse-events off. The renderer writes the event BBCode there
  # anyway (a rebake cooks it when the plugin goes on), so the stock
  # profile shows what a reader sees until then.
  PROFILES = {
    stock: {
      plugins: %w[discourse-details spoiler-alert poll],
      settings: {
      },
      features: {
        bbcode: false,
      },
    },
    all: {
      plugins: %w[discourse-details spoiler-alert poll discourse-events discourse-bbcode],
      settings: {
        "discourse_events_enabled" => true,
        "discourse_post_event_enabled" => true,
      },
      features: {
        bbcode: true,
      },
    },
    none: {
      plugins: [],
      settings: {
      },
      features: {
        details: false,
        spoiler: false,
        poll: false,
        post_event: false,
        bbcode: false,
      },
    },
  }.freeze

  # What the engine cooks per profile, for a check that has to know
  # whether BBCode becomes HTML or stays text: `[u]`, `[quote="…"]`, the
  # image options in the alt text (which Discourse trims) and the
  # `|attachment` marker of a file upload are Discourse core, the rest
  # comes with the plugins of the profile.
  COOKS = {
    stock: %i[underline quote image_options attachment details spoiler poll],
    all: %i[underline quote image_options attachment details spoiler poll post_event bbcode],
    none: %i[underline quote image_options attachment],
  }.freeze

  # One profile as a cooker, with the same +cook+ as MarkdownItCooker, so
  # RoundTripChecker can cook with either.
  Profile =
    Struct.new(:name) do
      def cook(markdown)
        DiscourseEngineCooker.cook(markdown, profile: name)
      end

      # @param feature [Symbol] :underline, or a key of the renderer's
      #   +features:+
      # @return [Boolean] whether the site of this profile cooks the
      #   BBCode of the feature
      def cooks?(feature)
        COOKS.fetch(name).include?(feature)
      end

      def features
        PROFILES.fetch(name).fetch(:features)
      end
    end

  # @param name [Symbol] a key of PROFILES
  # @return [Profile]
  def self.profile(name)
    Profile.new(name)
  end

  def self.missing
    if !CookProcess.node?
      "node is not on the PATH"
    elsif !File.file?(File.join(ENGINE, "engine.json"))
      "the Discourse engine is not built, run `#{SETUP}`"
    end
  end

  REQUIRED = ENV["DISCOURSE_ENGINE_REQUIRED"] == "1"
  SKIP_REASON =
    if !defined?(Nokogiri::HTML5)
      "Nokogiri::HTML5 not available on #{RUBY_ENGINE}"
    elsif !REQUIRED
      missing
    end

  @processes = {}

  # @param markdown [String]
  # @param profile [Symbol] a key of PROFILES
  # @return [String] the HTML Discourse cooks from +markdown+ on that site
  def self.cook(markdown, profile: :stock)
    process(profile).cook(markdown)
  end

  # @param profile [Symbol] a key of PROFILES
  # @return [Markbridge::Renderers::Discourse::Renderer] a renderer with
  #   the features of the profile; sizes pass through as they are
  def self.renderer(profile)
    features = PROFILES.fetch(profile).fetch(:features)
    sizes = IDENTITY if features[:bbcode]
    Markbridge.discourse_renderer(features:, sizes:)
  end

  def self.process(profile)
    @processes[profile] ||= start(PROFILES.fetch(profile))
  end

  def self.start(profile)
    reason = missing
    raise "Discourse engine cooker: #{reason}" if reason

    CookProcess.new(
      SCRIPT,
      "--engine",
      ENGINE,
      "--plugins",
      profile.fetch(:plugins).join(","),
      "--settings",
      JSON.generate(profile.fetch(:settings)),
    )
  end

  private_class_method :process, :start
end
