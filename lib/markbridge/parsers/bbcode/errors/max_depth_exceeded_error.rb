# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      class MaxDepthExceededError < StandardError
        def initialize(max)
          super("maximum parsing depth (#{max}) exceeded")
        end
      end
    end
  end
end
