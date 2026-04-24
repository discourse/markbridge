# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Token representing a closing BBCode tag like [/b]
      class TagEndToken < Token
        attr_reader :tag

        def initialize(tag:, pos:, source:)
          super(pos:, source:)
          @tag = tag.freeze
        end
      end
    end
  end
end
