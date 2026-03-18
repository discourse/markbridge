# frozen_string_literal: true

module Markbridge
  module Processors
    module DiscourseMarkdown
      module Detectors
        # Detects user and group mentions (@username, @groupname).
        #
        # @example Basic usage
        #   detector = Mention.new
        #   match = detector.detect("Hello @gerhard!", 6)
        #   match.node.name # => "gerhard"
        #   match.node.type # => :user (default)
        #
        # @example With type resolver
        #   resolver = ->(name) { name == "Testers" ? :group : :user }
        #   detector = Mention.new(type_resolver: resolver)
        #   match = detector.detect("@Testers", 0)
        #   match.node.type # => :group
        class Mention < Base
          # @param type_resolver [#call, nil] callable that takes a name and returns :user or :group
          def initialize(type_resolver: nil)
            @type_resolver = type_resolver
          end

          # Attempt to detect a mention at the given position.
          #
          # @param input [String] the full input string
          # @param pos [Integer] current position to check
          # @return [Match, nil] match result or nil if no match
          def detect(input, pos)
            return nil unless input[pos] == "@"
            return nil unless word_boundary?(input, pos)

            # Extract the username/group name
            name = extract_word(input, pos + 1)
            return nil if name.empty?

            end_pos = pos + 1 + name.length
            type = resolve_type(name)
            node = AST::Mention.new(name:, type:)

            Match.new(start_pos: pos, end_pos:, node:)
          end

          private

          def resolve_type(name)
            return :user unless @type_resolver

            @type_resolver.call(name) || :user
          end
        end
      end
    end
  end
end
