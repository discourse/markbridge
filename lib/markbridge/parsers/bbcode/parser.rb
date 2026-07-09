# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Parses BBCode into an AST using handlers from HandlerRegistry
      class Parser
        attr_reader :unknown_tags,
                    :auto_closed_tags_count,
                    :depth_exceeded_count,
                    :unclosed_raw_tags

        # Create a new parser with optional custom handlers
        # @param handlers [HandlerRegistry, nil] custom handler registry, defaults to HandlerRegistry.default
        # @yield [HandlerRegistry] optional block to customize the default registry
        # @example Using default handlers
        #   parser = Parser.new
        # @example Using custom handlers
        #   parser = Parser.new(handlers: my_registry)
        # @example Customizing default handlers
        #   parser = Parser.new do |registry|
        #     registry.register("quote", QuoteHandler.new)
        #   end
        def initialize(handlers: nil, &block)
          @handlers =
            if block_given?
              HandlerRegistry.build_from_default(&block)
            else
              handlers || HandlerRegistry.shared_default
            end
          @unknown_tags = Hash.new(0)
        end

        # Parse BBCode string into an AST
        # @param input [String] BBCode source
        # @return [AST::Document]
        def parse(input)
          @unknown_tags.clear

          normalized = normalize_line_endings(input)

          document = AST::Document.new
          context = ParserState.new(document)

          scanner = Scanner.new(normalized)
          parse_tokens(scanner, context)

          @auto_closed_tags_count = context.auto_closed_count
          @depth_exceeded_count = context.depth_exceeded_count
          @unclosed_raw_tags = context.unclosed_raw_tags
          document
        end

        private

        LINE_ENDING_RE = /\r\n?|[\u2028\u2029]+/
        private_constant :LINE_ENDING_RE

        # Normalize line endings (CR, CRLF, and Unicode separators)
        # @param input [String]
        # @return [String] the input itself when already normalized (LF-only)
        def normalize_line_endings(input)
          input.match?(LINE_ENDING_RE) ? input.gsub(LINE_ENDING_RE, "\n") : input
        end

        # Parse tokens using scanner
        # @param scanner [Scanner]
        # @param context [ParserState]
        def parse_tokens(scanner, context)
          tokens = PeekableEnumerator.new(scanner)

          while (token = tokens.next)
            case token
            when TextToken
              process_text(token, context)
            when TagStartToken
              process_tag_start(token, context, tokens)
            when TagEndToken
              process_tag_end(token, context, tokens)
            end
          end
        end

        # Process text token
        # @param token [TextToken]
        # @param context [ParserState]
        def process_text(token, context)
          context.add_child(AST::Text.new(token.text))
        end

        # Process opening tag
        # @param token [TagStartToken]
        # @param context [ParserState]
        # @param tokens [PeekableEnumerator]
        def process_tag_start(token, context, tokens)
          if (handler = @handlers[token.tag])
            handler.on_open(token:, context:, registry: @handlers, tokens:)
          else
            track_unknown_tag(token)
          end
        end

        # Process closing tag
        # @param token [TagEndToken]
        # @param context [ParserState]
        # @param tokens [PeekableEnumerator]
        def process_tag_end(token, context, tokens)
          if (handler = @handlers[token.tag])
            handler.on_close(token:, context:, registry: @handlers, tokens:)
          else
            track_unknown_tag(token)
          end
        end

        # Track unknown tag by name; the wrapper is ignored, children pass through.
        # @param token [Token]
        def track_unknown_tag(token)
          @unknown_tags[token.tag] += 1
        end
      end
    end
  end
end
