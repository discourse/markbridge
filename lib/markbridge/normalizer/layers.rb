# frozen_string_literal: true

module Markbridge
  class Normalizer
    # The built-in rule tables. Two layers: {common_mark} is objective
    # legality straight from the spec; {discourse} adds renderer policy on
    # top (and overrides where it disagrees).
    module Layers
      # Inline-only containers: CommonMark link text (§6.3) and
      # emphasis/heading content are inline, so block-level children break
      # the emitted Markdown.
      INLINE_CONTAINERS = [
        AST::Url,
        AST::Bold,
        AST::Italic,
        AST::Strikethrough,
        AST::Underline,
        AST::Superscript,
        AST::Subscript,
        AST::Heading,
      ].freeze

      # Nodes the Discourse renderer emits as block-level Markdown (blank
      # lines / block structure) — illegal inside an inline container.
      # Classification verified against the tags: Align, Details, Heading,
      # Paragraph, Quote, List/ListItem, Table/TableRow/TableCell, Poll and
      # Event bracket their output in "\n\n". Spoiler renders inline in
      # Markdown and single-line Code stays inline (handled by
      # {INLINE_CODE}), so both are deliberately absent.
      BLOCK_NODES = [
        AST::Quote,
        AST::Heading,
        AST::List,
        AST::ListItem,
        AST::Table,
        AST::TableRow,
        AST::TableCell,
        AST::Details,
        AST::Paragraph,
        AST::HorizontalRule,
        AST::Align,
        AST::Poll,
        AST::Event,
      ].freeze

      # Image-likes a link must not wrap. These render as valid CommonMark
      # inside a link (+[![alt](src)](url)+) but Discourse wants them hoisted
      # out. Block constructs (Quote/Poll/Event) are handled by the CommonMark
      # layer via {BLOCK_NODES}, since a block breaks *any* inline container.
      DISCOURSE_HOIST_FROM_URL = [AST::Image, AST::Upload, AST::Attachment].freeze

      # Keep an inline code span in a link (legal), hoist a block/fenced one
      # out. Mirrors +RenderingInterface#block_context?+: Code renders as a
      # fenced block iff a Text child contains a newline (the language alone
      # does not force a block).
      INLINE_CODE =
        lambda do |_boundary, node|
          block = node.children.any? { |c| c.instance_of?(AST::Text) && c.text.include?("\n") }
          block ? :hoist_after : :keep
        end

      class << self
        # CommonMark legality every renderer relies on.
        # @return [RuleSet]
        def common_mark
          rules = RuleSet.new

          # §6.3 "Links may not contain other links, at any level of
          # nesting." Unwrap the inner link, keeping its label text.
          rules.add(parent: AST::Url, child: AST::Url, strategy: :unwrap)

          # §6.1 A code span in a link label is legal only while it stays
          # inline.
          rules.add(parent: AST::Url, child: AST::Code, strategy: INLINE_CODE)

          # Inline-only containers may not hold block-level content.
          INLINE_CONTAINERS.each do |container|
            BLOCK_NODES.each do |block|
              next if container == block

              rules.add(parent: container, child: block, strategy: :hoist_after)
            end
          end

          rules
        end

        # Discourse renderer policy, layered on top of {common_mark}.
        # @return [RuleSet]
        def discourse
          rules = common_mark

          # A mention renders as literal @name — exactly what Discourse cooks
          # inside a link — so it is explicitly allowed (and silenced).
          rules.add(parent: AST::Url, child: AST::Mention, strategy: :keep)

          DISCOURSE_HOIST_FROM_URL.each do |child|
            rules.add(parent: AST::Url, child:, strategy: :hoist_after)
          end

          rules
        end
      end
    end
  end
end
