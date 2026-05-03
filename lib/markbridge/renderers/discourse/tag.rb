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
        # block (e.g. inside an HTML <table> fallback). Override and return
        # true when the tag emits valid HTML in html_mode and does not need a
        # blank-line "Markdown island" wrap. Defaults to false so that any
        # unaware tag — stubs, custom user tags — gets wrapped automatically.
        def html_mode_aware?
          false
        end
      end
    end
  end
end
