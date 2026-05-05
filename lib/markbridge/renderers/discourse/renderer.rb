# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Renders AST to Discourse-flavored Markdown in-memory.
      class Renderer
        attr_reader :postprocessor

        def initialize(tag_library: nil, escaper: nil, html_escaper: nil, postprocessor: nil)
          @tag_library = tag_library || TagLibrary.default
          @escaper = escaper || MarkdownEscaper.new
          @html_escaper = html_escaper || HtmlEscaper
          @postprocessor = postprocessor || Postprocessor::DEFAULT
          # @interface_cache and @emission_buffer are lazily initialized
          # in #render's top-level call and reset to nil after the call
          # completes. No init needed here — unset ivars return nil
          # under `.nil?` checks.
        end

        # Render a node to Markdown
        # @param node [AST::Node]
        # @param context [RenderContext] rendering context with parent chain
        # @return [String]
        def render(node, context: RenderContext.new)
          root_call = @interface_cache.nil?
          if root_call
            @interface_cache = {}
            @emission_buffer = {}
          end

          tag = @tag_library[node.class]
          if tag
            interface = interface_for(context)
            return tag.render(node, interface)
          end

          case node
          when AST::Element # Document is an Element subclass
            render_children(node, context:)
          when AST::MarkdownText
            render_markdown_text(node, context)
          when AST::Text
            render_text(node, context)
          else
            ""
          end
        ensure
          # Drop the per-call interface cache; keep @emission_buffer so
          # callers can drain it via #emissions after render returns.
          # The buffer is reset on the next root call.
          @interface_cache = nil if root_call
        end

        # Append a record to the emission buffer for the current
        # render call. Called by Tags through
        # +RenderingInterface#emit+. No-op outside a render call.
        # @param key [Symbol]
        # @param payload [Object]
        def record_emission(key, payload)
          (@emission_buffer[key] ||= []) << payload if @emission_buffer
        end

        # Snapshot the emission buffer, run the block, and roll back
        # to the snapshot if the block's return value is discarded by
        # the caller. Used by tags that perform a throwaway render
        # pass (e.g. +TableTag+'s Markdown-then-HTML fallback).
        #
        # The block decides whether to keep emissions by calling
        # +commit+ on the yielded controller. If the block exits
        # without committing, emissions made inside the block are
        # discarded.
        #
        # @yieldparam controller [#commit]
        # @return [Object] the block's return value
        def with_provisional_emissions
          snapshot = snapshot_emissions
          committed = false
          controller = ProvisionalController.new(-> { committed = true })

          result = yield(controller)
          rollback_emissions(snapshot) unless committed
          result
        end

        # Drain the emission buffer for the *most recent* root render
        # call. Returns +{}+ when no emissions were recorded or no
        # render is in progress.
        # @return [Hash{Symbol => Array}]
        def emissions
          (@emission_buffer || {}).transform_values(&:dup)
        end

        # Render all children of a node
        # @param node [AST::Element]
        # @param context [RenderContext] rendering context
        # @return [String]
        def render_children(node, context:)
          result = +""
          node.children.each do |child|
            part = render(child, context:)
            next if part.empty?

            # Integer-byte check avoids allocating substrings for the
            # per-child adjacency probe. EMPHASIS_DELIMITER_BYTES.include?
            # over a 4-element Set is O(1).
            if !result.empty? && (last_byte = result.getbyte(-1)) == part.getbyte(0) &&
                 EMPHASIS_DELIMITER_BYTES.include?(last_byte)
              result << EMPHASIS_BOUNDARY
            end
            result << part
          end
          result
        end

        private

        def snapshot_emissions
          return {} unless @emission_buffer

          @emission_buffer.transform_values(&:dup)
        end

        def rollback_emissions(snapshot)
          return unless @emission_buffer

          @emission_buffer.replace(snapshot)
        end

        # Yielded by +#with_provisional_emissions+; calling +commit+
        # tells the renderer to keep emissions made inside the block.
        ProvisionalController =
          Struct.new(:commit_proc) do
            def commit
              commit_proc.call
            end
          end
        private_constant :ProvisionalController

        # Inserted between sibling outputs when their adjacent characters
        # would merge into a longer Markdown emphasis delimiter run (e.g.
        # `***` + `*...` becoming `****...`). The HTML comment is invisible
        # in rendered output but breaks the delimiter run during Markdown
        # parsing.
        EMPHASIS_BOUNDARY = "<!---->"
        # Bytes where adjacent runs merge into a single longer run during
        # Markdown parsing: emphasis (* _), strikethrough (~), code spans (`).
        EMPHASIS_DELIMITER_BYTES = Set[42, 95, 126, 96].freeze
        private_constant :EMPHASIS_BOUNDARY, :EMPHASIS_DELIMITER_BYTES

        def interface_for(context)
          @interface_cache[context.object_id] ||= RenderingInterface.new(self, context)
        end

        # In html_mode, surround pre-formatted Markdown with blank lines so that
        # CommonMark terminates the enclosing HTML block (e.g. <table>) and
        # parses the content as Markdown before the closing tags reopen another
        # HTML block.
        def render_markdown_text(node, context)
          context.html_mode? ? "\n\n#{node.text}\n\n" : node.text
        end

        def render_text(node, context)
          # In html_mode even inside a code block we must HTML-escape, otherwise a
          # stray `<` in a code cell would break the surrounding <td>.
          if context.has_parent?(AST::Code)
            context.html_mode? ? @html_escaper.escape(node.text) : node.text
          elsif context.html_mode?
            @html_escaper.escape(node.text)
          else
            @escaper.escape(node.text)
          end
        end
      end
    end
  end
end
