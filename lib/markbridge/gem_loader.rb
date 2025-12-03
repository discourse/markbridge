# frozen_string_literal: true

module Markbridge
  module GemLoader
    class << self
      def require_gem(gem, feature:)
        require gem.to_s
      rescue LoadError
        raise LoadError, missing_message(gem, feature)
      end

      private

      def missing_message(gem, feature)
        gem_name = gem.to_s
        [
          "#{gem_name.capitalize} is required for #{feature}.",
          "Add 'gem \"#{gem_name}\"' to your Gemfile or install it with 'gem install #{gem_name}'.",
        ].join(" ")
      end
    end
  end
end
