# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Wrapper around a scanner that allows peeking at upcoming tokens
      # without consuming them.
      #
      # This class buffers tokens pulled from a scanner (which must implement
      # `next_token`) so callers can:
      # - inspect the next token with {#peek} without advancing the scanner
      # - inspect several upcoming tokens with {#peek_ahead}
      # - consume tokens with {#next}
      #
      # The enumerator is lazy: tokens are only requested from the scanner
      # when needed. Once the underlying scanner returns `nil`, the enumerator
      # is marked finished and further peeks return `nil` (for single peeks)
      # or an empty array (for multi-peeks).
      #
      # @example Basic usage
      #   scanner = YourScanner.new("...") # responds to `next_token`
      #   enum = PeekableEnumerator.new(scanner)
      #   enum.peek        # => next token (no consume)
      #   enum.peek_ahead(3) # => array of up to 3 upcoming tokens
      #   enum.next        # => consumes and returns next token
      #
      # @see Markbridge::Parsers::BBCode::Scanner
      class PeekableEnumerator
        # Initialize a new PeekableEnumerator.
        #
        # @param scanner [Object] the scanner object that responds to `next_token`
        def initialize(scanner)
          @scanner = scanner
          @peeked = []
        end

        # Consume and return the next token.
        # @return [Object, nil] next token or `nil` when exhausted
        def next
          ensure_peeked(1)
          @peeked.shift
        end

        # Return whether more tokens are available.
        # @return [Boolean]
        def has_next?
          ensure_peeked(1)
          !@peeked.empty?
        end

        # Peek at the next single token without consuming it.
        # @return [Object, nil] the next token or `nil` when exhausted
        def peek
          ensure_peeked(1)
          @peeked.first
        end

        # Peek ahead at up to `count` upcoming tokens without consuming them.
        # @param count [Integer] number of tokens to peek ahead (clamped to 0..)
        # @return [Array<Object>] array of upcoming tokens (possibly empty)
        def peek_ahead(count)
          count = [count, 0].max
          ensure_peeked(count)
          @peeked.first(count)
        end

        alias next_token next

        private

        # Ensure at least `count` items are present in the peek buffer.
        def ensure_peeked(count)
          while @peeked.size < count
            value = @scanner.next_token
            break if value.nil?

            @peeked << value
          end
        end
      end
    end
  end
end
