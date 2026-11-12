# frozen_string_literal: true

require_relative "normalizer/rule_set"
require_relative "normalizer/report"
require_relative "normalizer/text_projection"
require_relative "normalizer/carrier"
require_relative "normalizer/walker"

module Markbridge
  # Rewrites an AST so the renderer only gets markup the target format can
  # express. It runs once, between parse and render. The default rules are
  # CommonMark legality: no link inside a link, no block element inside an
  # inline container, and an inline-only code span. Each match resolves to a
  # strategy (+:keep+, +:hoist_after+, +:unwrap+, +:textify+, +:drop+, or a
  # callable) that the {Walker} applies.
  #
  # Discourse-specific policy (for example, moving an image out of a link) is
  # not built in. A consumer adds those with {#rule}.
  #
  # @example The default, reused across conversions
  #   Markbridge::Normalizer.shared_default
  #
  # @example A customized normalizer
  #   n = Markbridge::Normalizer.default
  #   n.rule(parent: AST::Url, child: AST::Image, strategy: :hoist_after)
  #   Markbridge.convert(input, format: :bbcode, normalize: n)
  #
  # @example List what would change, without changing it
  #   Markbridge::Normalizer.default.violations(ast) # => [...]
  class Normalizer
    # The strategy symbols a rule may resolve to.
    STRATEGIES = %i[keep split hoist_after unwrap textify drop].freeze

    EMPTY_STACK = [].freeze
    private_constant :EMPTY_STACK

    # Containers that hold inline content only: a link's text (CommonMark
    # §6.3), and emphasis and heading content. A color and a size are
    # written as a BBCode tag or as nothing around a line of text, like
    # emphasis, and a mail address is a link.
    INLINE_CONTAINERS = [
      AST::Url,
      AST::Email,
      AST::Bold,
      AST::Italic,
      AST::Strikethrough,
      AST::Underline,
      AST::Superscript,
      AST::Subscript,
      AST::Insertion,
      AST::Deletion,
      AST::Highlight,
      AST::Color,
      AST::Size,
      AST::Heading,
    ].freeze

    # The nodes that are written as a link.
    LINKS = [AST::Url, AST::Email].freeze

    # AST nodes the Discourse renderer prints as block-level Markdown (their
    # output has blank lines around it). One inside an inline container breaks
    # that container, so it is moved out. Spoiler and single-line Code without
    # a forced +block+ flag stay inline and are not listed (Code is handled by
    # {KEEP_INLINE_CODE}).
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

    # The inline elements whose formatting goes with a block that is
    # split out of them (see {Carrier}): the block was shown bold, in a
    # color or as a link, and its text still is. A heading and a
    # paragraph are split too, but there is nothing to take along.
    CARRIED = [
      AST::Url,
      AST::Email,
      AST::Bold,
      AST::Italic,
      AST::Strikethrough,
      AST::Underline,
      AST::Superscript,
      AST::Subscript,
      AST::Insertion,
      AST::Deletion,
      AST::Highlight,
      AST::Color,
      AST::Size,
      # An inline one: a block spoiler is a block and never around one
      # that is split out.
      AST::Spoiler,
    ].freeze

    # How a block leaves the container +boundary+. A heading stays one
    # heading and the block goes behind it. A block spoiler may hold
    # blocks, so it passes the question on to what is inside of it.
    # Everything else is split around the block, which keeps the order
    # of the text.
    MOVE =
      lambda do |boundary|
        if boundary.is_a?(AST::Heading)
          :hoist_after
        elsif boundary.is_a?(AST::Spoiler) && boundary.block
          :pass
        else
          :split
        end
      end

    # A code span may stay inside an inline container while it is on one line.
    # A fenced or multi-line block is moved out. This matches
    # +RenderingInterface#block_context?+: Code prints as a fenced block when
    # its +block+ flag is set or a Text child has a newline (the language alone
    # does not make it a block).
    KEEP_INLINE_CODE = ->(boundary, node) { block_code?(node) ? MOVE.call(boundary) : :keep }

    # A spoiler inside a line of text may stay in an inline container. One
    # with its +block+ flag set is written on lines of its own and is
    # moved out.
    KEEP_INLINE_SPOILER = ->(boundary, node) { node.block ? MOVE.call(boundary) : :keep }

    # A block in a block or a block in a container, by the class of the
    # container.
    MOVE_BLOCK = ->(boundary, _node) { MOVE.call(boundary) }

    class << self
      # @param node [AST::Code]
      # @return [Boolean] whether the code is written as a fenced block
      def block_code?(node)
        node.block || node.children.any? { |c| c.instance_of?(AST::Text) && c.text.include?("\n") }
      end

      # @param node [AST::Node]
      # @return [Boolean] whether the node is written on lines of its own.
      #   Not every code and not every spoiler is: a code span and an
      #   inline spoiler are a part of their line.
      def own_lines?(node)
        case node
        when AST::Code
          block_code?(node)
        when AST::Spoiler
          node.block ? true : false
        else
          BLOCK_NODES.any? { |klass| node.is_a?(klass) }
        end
      end

      # A fresh, customizable normalizer with the default rules. Add more with
      # {#rule}.
      # @return [Normalizer]
      def default
        new(build_rules)
      end

      # The default normalizer, built once and frozen, reused across
      # conversions. +#normalize+ and +#violations+ keep no state on the
      # instance, so one frozen instance is safe to reuse, also across threads.
      # @return [Normalizer] the same frozen instance on every call
      def shared_default
        @shared_default ||= default.freeze
      end

      private

      def build_rules
        rules = RuleSet.new

        # §6.3 A link may not contain another link, at any depth. Unwrap the
        # inner link and keep its text. A mail address is a link too.
        LINKS.each do |outer|
          LINKS.each { |inner| rules.add(parent: outer, child: inner, strategy: :unwrap) }
        end

        # A paragraph is a line of text too. It is no inline container,
        # it is a block itself, but a block in it is split out the same
        # way. So is a block in an inline spoiler (see MOVE for a block
        # spoiler).
        [*INLINE_CONTAINERS, AST::Paragraph, AST::Spoiler].each do |container|
          rules.add(parent: container, child: AST::Code, strategy: KEEP_INLINE_CODE)
          rules.add(parent: container, child: AST::Spoiler, strategy: KEEP_INLINE_SPOILER)

          BLOCK_NODES.each do |block|
            rules.add(parent: container, child: block, strategy: MOVE_BLOCK)
          end
        end

        # Heading is a container and a block. A heading in a heading does
        # not move out, it is one heading, like a link in a link is one
        # link: the text stays where it is. This replaces the rule the
        # loop above has added for the pair. (+add+ returns the rule set.)
        rules.add(parent: AST::Heading, child: AST::Heading, strategy: :unwrap)
      end
    end

    # @param rule_set [RuleSet]
    def initialize(rule_set)
      @rules = rule_set
    end

    # Add or override a rule. Chainable. A rule for a +(parent, child)+ pair
    # that already exists is replaced. Raises on a frozen ({shared_default})
    # instance; build a fresh one with {.default}.
    #
    # @param parent [Class] ancestor AST class
    # @param child [Class] contained AST class
    # @param strategy [Symbol, #call] one of {STRATEGIES} or a callable
    # @return [self]
    def rule(parent:, child:, strategy:)
      @rules.add(parent:, child:, strategy:)
      self
    end

    # Rewrite +ast+ in place so it satisfies the rules.
    #
    # @param ast [AST::Document, AST::Element]
    # @return [Array<Hash>] a report of what changed (empty when nothing did),
    #   one +{parent:, child:, strategy:, count:}+ row per distinct change.
    def normalize(ast)
      report = Report.new
      Walker.new(@rules, report).call(ast)
      report.to_a
    end

    # List the violations in +ast+ without changing it.
    #
    # @param ast [AST::Document, AST::Element]
    # @return [Array<Hash>] +{parent:, child:, strategy:}+ per occurrence
    def violations(ast)
      found = []
      # Per-call cache for RuleSet#resolve's ancestry analysis; keeps the
      # Normalizer instance itself free of state, so a frozen shared
      # instance stays safe across threads.
      collect_violations(ast, EMPTY_STACK, found, {})
      found
    end

    def freeze
      @rules.freeze
      super
    end

    private

    def collect_violations(element, ancestors, found, walk_cache)
      stack = ancestors + [element]
      element.children.each do |child|
        strategy, boundary = @rules.decide(child, stack, walk_cache)
        unless strategy.nil? || strategy == :keep
          found << {
            parent: Report.short_name(boundary.class),
            child: Report.short_name(child.class),
            strategy:,
          }
        end
        collect_violations(child, stack, found, walk_cache) if child.is_a?(AST::Element)
      end
    end
  end
end
