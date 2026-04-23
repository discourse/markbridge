# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Token representing text content
      class TextToken < Token
        attr_reader :text

        def initialize(text:, pos:)
          super(pos:, source: text)
          @text = text.freeze
        end

        def inspect
          "#<TextToken #{text.inspect}>"
        end
      end
    end
  end
end
