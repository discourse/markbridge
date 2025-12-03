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
      end
    end
  end
end
