# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Result object for raw content collection
      class RawContentResult
        attr_reader :content, :closed

        def initialize(content:, closed:)
          @content = content
          @closed = closed
        end

        def closed?
          @closed
        end

        def unclosed?
          !@closed
        end
      end
    end
  end
end
