# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      class Token
        attr_reader :pos, :source

        def initialize(pos: 0, source: nil)
          @pos = pos
          @source = source
        end
      end
    end
  end
end
