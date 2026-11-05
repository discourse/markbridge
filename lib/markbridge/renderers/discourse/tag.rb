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
        # 1. Emit raw HTML (e.g. `<strong>` for `**`), with no blank line
        #    in it.
        # 2. Write the Markdown through `interface.markdown_island`, which
        #    puts it between blank lines inside a `<div>`: the blank lines
        #    close the HTML block, CommonMark parses the content as a
        #    Markdown island, and the `</div>` line re-opens the block.
        #    Visible: blank-line wrapping forces a `<p>` margin around
        #    inline content, so prefer (1) when the tag has an HTML form.
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

        # The list the output of this tag starts with, when it starts with
        # one. Two lists of the same kind with only whitespace between
        # them cook as one list, so the renderer keeps track of the last
        # list it wrote (see RenderingInterface#previous_list) and ListTag
        # puts a separator in front of a list that would continue it. A
        # tag whose output starts with the output of a child, like the
        # plain form of DetailsTag, answers with that child's list:
        # +interface.leading_list(element, children: true)+. ListTag
        # answers with the list itself. The default is nil: the output
        # starts with something of its own, or with nothing.
        #
        # @param element [AST::Node]
        # @param interface [RenderingInterface]
        # @return [AST::List, nil]
        def leading_list(_element, _interface)
        end

        # The list the output of this tag ends with, when it ends with
        # one, see #leading_list. +interface.trailing_list(element,
        # children: true)+ is the answer of the last child with something
        # in it.
        #
        # @param element [AST::Node]
        # @param interface [RenderingInterface]
        # @return [AST::List, nil]
        def trailing_list(_element, _interface)
        end

        # A tag that renders only the element's children, with the element
        # pushed on the parent chain. Tag dispatch matches by ancestry, so
        # a subclass normally inherits its base class tag; register
        # PASSTHROUGH for the subclass to opt out — the exact-class hit
        # wins and the base tag is not used.
        PASSTHROUGH =
          Class
            .new(self) do
              def render(element, interface)
                interface.render_children(element, context: interface.with_parent(element))
              end

              # The output is the children's, so its edges are theirs.
              def leading_list(element, interface)
                interface.leading_list(element, children: true)
              end

              def trailing_list(element, interface)
                interface.trailing_list(element, children: true)
              end
            end
            .new
            .freeze
      end
    end
  end
end
