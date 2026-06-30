# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "benchmark"
gem "benchmark-ips"
gem "csv"
gem "commonmarker", install_if: -> { RUBY_ENGINE == "ruby" }
gem "lefthook"
gem "nokogiri"
gem "puma"
gem "rackup"
gem "rake"
gem "rspec"
gem "rubocop-discourse-base"
gem "rubocop-rspec"
gem "rubycritic"
gem "simplecov"
gem "sinatra"
gem "syntax_tree"

# mutant only runs in the dedicated MRI `mutation` CI job. Keep it (and its
# rdoc → rbs chain, which has a native extension) off JRuby/TruffleRuby, the
# same way commonmarker is guarded above.
gem "mutant", "~> 0.16", install_if: -> { RUBY_ENGINE == "ruby" }
gem "mutant-rspec", "~> 0.16", install_if: -> { RUBY_ENGINE == "ruby" }
