# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Base class for rendering tags
      # Can be subclassed for complex tags or initialized with a block for simple tags
      class Tag
        # Initialize a tag
        # @param block [Proc, nil] optional block for rendering
        def initialize(&block)
          @render_block = block
        end

        # Render a node to Discourse Markdown.
        #
        # When `interface.html_mode?` is true the surrounding output is
        # a CommonMark HTML block (§4.6): content is treated as raw HTML
        # and is not re-parsed for Markdown except across blank lines.
        # Every tag must pick one of two contracts:
        #
        # 1. Emit raw HTML (e.g. `<strong>` for `**`).
        # 2. Wrap Markdown output in `\n\n…\n\n` so the blank lines close
        #    the HTML block, CommonMark parses the content as a Markdown
        #    island, then re-opens. Visible: blank-line wrapping forces a
        #    `<p>` margin around inline content, so prefer (1) when the
        #    tag has an HTML form.
        #
        # @param element [AST::Node] the node to render
        # @param interface [RenderingInterface] the rendering interface
        # @return [String] the rendered markdown
        def render(element, interface)
          if @render_block
            @render_block.call(element, interface)
          else
            raise NotImplementedError, "#{self.class} must implement #render or provide a block"
          end
        end
      end
    end
  end
end
