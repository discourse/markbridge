# frozen_string_literal: true

require_relative "lib/markbridge/version"

Gem::Specification.new do |spec|
  spec.name = "markbridge"
  spec.version = Markbridge::VERSION
  spec.authors = ["Discourse Team"]

  spec.summary =
    "Converts BBCode, HTML, MediaWiki, and TextFormatter markup to Discourse-flavored Markdown"
  spec.description =
    "Markbridge parses multiple markup formats (BBCode, HTML, MediaWiki wikitext, " \
      "s9e/TextFormatter XML) into a shared AST and renders them as Discourse-flavored " \
      "Markdown. Built for forum migrations to Discourse, with extensible parsers and renderers."

  spec.homepage = "https://github.com/discourse/markbridge"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/discourse/markbridge"

  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "LICENSE.txt"]
  spec.require_paths = ["lib"]
end
