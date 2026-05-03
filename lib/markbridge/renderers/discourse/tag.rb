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

        # Render a node to Discourse Markdown
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

        # Whether this tag's output is safe to splice directly into an HTML
        # block (e.g. inside an HTML <table> fallback).
        #
        # When `interface.html_mode?` is true, the tag is rendering inside an
        # HTML container that CommonMark won't re-enter Markdown parsing on
        # except across blank lines. Two contracts are valid:
        #
        # 1. Override `render` to emit an HTML equivalent in html_mode (e.g.
        #    `<strong>` instead of `**`, `<ul><li>` instead of `- `), and
        #    override this method to return `true`. The renderer splices your
        #    output verbatim into the surrounding HTML block.
        #
        # 2. Do nothing. Leave this method returning `false`. The renderer
        #    wraps your tag's normal Markdown output in `\n\n…\n\n` so
        #    CommonMark closes the HTML block, parses the Markdown island,
        #    then reopens the HTML block. Safe but visible: in table cells
        #    the wrapping creates `<p>…</p>` with margin around inline
        #    content, which is usually undesirable.
        #
        # Pick (1) for any tag that can sensibly emit HTML; pick (2) for
        # tags whose Markdown form is strictly preferable (e.g. text-only
        # output that already round-trips through CommonMark unchanged).
        def html_mode_aware?
          false
        end
      end
    end
  end
end
