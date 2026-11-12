# frozen_string_literal: true

module Markbridge
  class Normalizer
    # Puts copies of inline elements around the inline content of a
    # block, for the +:split+ strategy. A quote that leaves bold keeps
    # the bold this way: every line of text in the quote gets a bold of
    # its own, in a paragraph, a list item or a table cell, at any
    # depth. Code is left alone, it shows no formatting.
    #
    #   Carrier.call(quote, [bold])
    #   # Quote[Paragraph["a"], List[ListItem["b"]]]
    #   # => Quote[Paragraph[Bold["a"]], List[ListItem[Bold["b"]]]]
    module Carrier
      # Blocks whose children are one line of text.
      LINES = [AST::Paragraph, AST::Heading].freeze
      # Blocks whose children are blocks, or text between blocks.
      CONTAINERS = [
        AST::Quote,
        AST::List,
        AST::ListItem,
        AST::Table,
        AST::TableRow,
        AST::TableCell,
        AST::Details,
        AST::Align,
        AST::Spoiler,
      ].freeze
      NOT_BLANK = /[^[:space:]]/
      private_constant :LINES, :CONTAINERS, :NOT_BLANK

      class << self
        # @param block [AST::Node] the block that is moved, changed in place
        # @param wrappers [Array<AST::Element>] the inline elements it
        #   was in, the outermost first. Copies of them are made, without
        #   their children.
        # @param copies [#<<] gets every copy that is made
        # @return [void]
        def call(block, wrappers, copies)
          return if wrappers.empty?

          if LINES.any? { |klass| block.is_a?(klass) }
            block.replace_children(wrapped(block.children, wrappers, copies))
          elsif CONTAINERS.any? { |klass| block.is_a?(klass) }
            block.replace_children(with_wrapped_runs(block.children, wrappers, copies))
          end
        end

        private

        # The children with every run of inline nodes between two blocks
        # wrapped, and the blocks carried into in turn.
        def with_wrapped_runs(children, wrappers, copies)
          out = []
          run = []
          children.each do |child|
            if Normalizer.own_lines?(child)
              out.concat(wrapped(run, wrappers, copies))
              run = []
              call(child, wrappers, copies)
              out << child
            else
              run << child
            end
          end
          out.concat(wrapped(run, wrappers, copies))
        end

        # @return [Array<AST::Node>] the run in the wrappers, or the run
        #   itself when it shows nothing
        def wrapped(run, wrappers, copies)
          return run unless run.any? { |node| visible?(node) }

          wrappers.reverse_each do |wrapper|
            copy = wrapper.dup.replace_children(run)
            copies << copy
            run = [copy]
          end
          run
        end

        def visible?(node)
          !node.instance_of?(AST::Text) || node.text.match?(NOT_BLANK)
        end
      end
    end
  end
end
