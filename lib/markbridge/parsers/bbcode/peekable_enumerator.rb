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
          @finished = false
        end

        # Consume and return the next token.
        #
        # If there are tokens in the internal buffer (from prior peeks) the
        # buffered token is returned. Otherwise, the next token is requested
        # from the underlying scanner via `next_token`.
        #
        # @return [Object, nil] next token or `nil` when exhausted
        def next
          return @peeked.shift if @peeked.any?
          return nil if @finished

          value = @scanner.next_token
          @finished = true if value.nil?
          value
        end

        # Return whether more tokens are available.
        #
        # This will attempt to fetch one token from the scanner if necessary
        # to determine whether more tokens remain.
        #
        # @return [Boolean] `true` if at least one token is available
        def has_next?
          return true if @peeked.any?
          return false if @finished

          value = @scanner.next_token
          if value.nil?
            @finished = true
            false
          else
            @peeked << value
            true
          end
        end

        # Peek at the next single token without consuming it.
        #
        # If the enumerator has been exhausted this returns `nil`.
        #
        # @return [Object, nil] the next token or `nil` when exhausted
        def peek
          return @peeked.first if @peeked.any?
          return nil if @finished

          ensure_peeked(1)
          @peeked.first
        end

        # Peek ahead at up to `count` upcoming tokens without consuming them.
        #
        # The method will return an array with at most `count` elements.
        # If fewer tokens remain, a shorter array is returned. When the
        # enumerator is exhausted an empty array is returned.
        #
        # @param count [Integer] number of tokens to peek ahead (non\-negative)
        # @return [Array<Object>] array of upcoming tokens (possibly empty)
        def peek_ahead(count)
          return [] if count <= 0

          ensure_peeked(count)
          @peeked.take(count)
        end

        alias next_token next

        private

        # Ensure at least `count` items are present in the peek buffer.
        #
        # This will repeatedly call `next_token` on the scanner until the
        # buffer contains `count` items or the scanner returns `nil`.
        #
        # @param count [Integer] desired buffer size
        # @return [void]
        def ensure_peeked(count)
          while !@finished && @peeked.size < count
            value = @scanner.next_token
            if value.nil?
              @finished = true
              break
            end
            @peeked << value
          end
        end
      end
    end
  end
end
