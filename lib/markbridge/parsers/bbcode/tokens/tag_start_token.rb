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
          # Explicit formatting — Ruby 3.4 changed Hash#inspect from
          # `{:key=>"val"}` to the shorthand `{key: "val"}`, so using
          # `attrs.inspect` produces version-dependent output.
          attrs_str =
            if attrs.empty?
              ""
            else
              " {#{attrs.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")}}"
            end
          "#<TagStartToken [#{tag}]#{attrs_str}>"
        end
      end
    end
  end
end
