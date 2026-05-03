# frozen_string_literal: true

module Markbridge
  module Processors
    module DiscourseMarkdown
      # Result of scanning Discourse Markdown
      # @attr_reader markdown [String] the processed markdown with placeholders
      # @attr_reader nodes [Array<AST::Node>] extracted AST nodes in order of appearance
      ScanResult = Data.define(:markdown, :nodes)

      # Single-pass scanner for Discourse Markdown that extracts specific constructs
      # (mentions, polls, events, uploads) while preserving all other content unchanged.
      #
      # The scanner respects code blocks (fenced, indented, and inline) and will not
      # extract constructs that appear within code.
      #
      # @example Basic usage
      #   scanner = Scanner.new
      #   result = scanner.scan("Hello @gerhard!")
      #   result.nodes.first # => AST::Mention
      #
      # @example With custom tag library for rendering
      #   scanner = Scanner.new(tag_library: my_library)
      #   result = scanner.scan(input)
      #   result.markdown # => "Hello <<MENTION:1>>!"
      #
      # @example With mention type resolver
      #   scanner = Scanner.new(mention_resolver: ->(name) {
      #     groups.include?(name) ? :group : :user
      #   })
      #   result = scanner.scan("@Testers and @gerhard")
      #   result.nodes[0].type # => :group
      #   result.nodes[1].type # => :user
      class Scanner
        # Default detectors in priority order
        DEFAULT_DETECTORS = [
          Detectors::Poll,
          Detectors::Event,
          Detectors::Upload,
          Detectors::Mention,
        ].freeze

        # Characters that can start a construct (for fast bailout)
        TRIGGER_CHARS = Set.new(["@", "[", "!"]).freeze

        # @param detectors [Array<Class>] detector classes to use (instantiated automatically)
        # @param tag_library [Renderers::Discourse::TagLibrary, nil] tag library for rendering placeholders
        # @param mention_resolver [#call, nil] callable that takes a name and returns :user or :group
        def initialize(detectors: DEFAULT_DETECTORS, tag_library: nil, mention_resolver: nil)
          @detector_instances = build_detectors(detectors, mention_resolver)
          @tag_library = tag_library
          # @code_tracker / @result / @nodes / @node_index / @pos / @input /
          # @line_start are set by #scan before use; no defensive init needed.
        end

        # Scan input and extract constructs.
        #
        # @param input [String] Discourse Markdown input
        # @return [ScanResult] result containing processed markdown and extracted nodes
        def scan(input)
          @code_tracker = CodeBlockTracker.new
          @result = +""
          @nodes = []
          @node_index = 0
          @pos = 0
          @input = input.to_s
          @line_start = true

          scan_input

          ScanResult.new(markdown: @result, nodes: @nodes)
        end

        private

        def build_detectors(detectors, mention_resolver)
          detectors.map do |klass|
            if klass == Detectors::Mention
              klass.new(type_resolver: mention_resolver)
            else
              klass.new
            end
          end
        end

        def scan_input
          while @pos < @input.length
            # Check for fenced code block boundary at line start
            if @line_start
              next if advance_code_boundary(:check_fenced_boundary)
              next if advance_code_boundary(:check_indented_boundary)
            end

            # Check for inline code boundary. check_inline_boundary's
            # own fenced/indented guard means we don't need to pre-check
            # here — it'll just return nil in those cases.
            if @input[@pos] == "`"
              new_pos = @code_tracker.check_inline_boundary(@input, @pos)
              if new_pos
                @result << @input[@pos...new_pos]
                @pos = new_pos
                @line_start = false
                next
              end
            end

            # If in code, pass through unchanged
            if @code_tracker.in_code?
              @result << @input[@pos]
              @line_start = @input[@pos] == "\n"
              @pos += 1
              next
            end

            # Fast path: only try detectors if current char could start a construct
            char = @input[@pos]
            if TRIGGER_CHARS.include?(char)
              match = detect_at_position
              if match
                handle_match(match)
                next
              end
            end

            @result << char
            @line_start = char == "\n"
            @pos += 1
          end
        end

        def advance_code_boundary(method)
          new_pos = @code_tracker.public_send(method, @input, @pos, line_start: true)
          return false unless new_pos

          # check_fenced_boundary / check_indented_boundary always stop
          # at pos_after_line, which is either after a "\n" or at EOF.
          # After-newline → @line_start should be true; at EOF the
          # outer `while @pos < @input.length` exits and @line_start
          # is unobservable. Setting true unconditionally drops the
          # `@input[new_pos - 1] == "\n"` dance.
          @result << @input[@pos...new_pos]
          @pos = new_pos
          @line_start = true
          true
        end

        def detect_at_position
          @detector_instances.each do |detector|
            match = detector.detect(@input, @pos)
            return match if match
          end
          nil
        end

        def handle_match(match)
          node = match.node
          @nodes << node
          @result << render_placeholder(node)

          # Every detector shipped today matches content that ends on a
          # non-newline byte (`]`, `)`, `_`, alphanumeric), so @line_start
          # is always false after a successful match. If a future custom
          # detector produces a match whose end_pos sits right after
          # "\n", re-introduce the `@input[@pos - 1] == "\n"` check.
          @pos = match.end_pos
          @line_start = false
          @node_index += 1
        end

        def render_placeholder(node)
          if @tag_library
            tag = @tag_library[node.class]
            return tag.render(node, nil) if tag
          end

          default_placeholder(node)
        end

        def default_placeholder(node)
          case node
          when AST::Mention
            "<<MENTION:#{@node_index}:#{node.name}>>"
          when AST::Poll
            "<<POLL:#{@node_index}:#{node.name}>>"
          when AST::Event
            "<<EVENT:#{@node_index}:#{node.name}>>"
          when AST::Upload
            "<<UPLOAD:#{@node_index}:#{node.sha1}>>"
          end
        end
      end
    end
  end
end
