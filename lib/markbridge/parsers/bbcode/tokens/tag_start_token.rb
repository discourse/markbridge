# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Token representing an opening BBCode tag like [b] or [url=...]
      class TagStartToken < Token
        attr_reader :tag, :attrs

        def initialize(tag:, attrs:, pos:, source:)
          super(pos:, source:)
          @tag = tag.freeze
          @attrs = attrs.freeze
        end

        def inspect
          attrs_str = attrs.empty? ? "" : " #{attrs.inspect}"
          "#<TagStartToken [#{tag}]#{attrs_str}>"
        end
      end
    end
  end
end
