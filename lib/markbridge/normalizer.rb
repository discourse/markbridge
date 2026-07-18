# frozen_string_literal: true

require_relative "normalizer/rule_set"
require_relative "normalizer/report"
require_relative "normalizer/text_projection"
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
    STRATEGIES = %i[keep hoist_after unwrap textify drop].freeze

    EMPTY_STACK = [].freeze
    private_constant :EMPTY_STACK

    # Containers that hold inline content only: a link's text (CommonMark
    # §6.3), and emphasis and heading content.
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

    # AST nodes the Discourse renderer prints as block-level Markdown (their
    # output has blank lines around it). One inside an inline container breaks
    # that container, so it is moved out. Spoiler and single-line Code stay
    # inline and are not listed (Code is handled by {KEEP_INLINE_CODE}).
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

    # A code span may stay inside an inline container while it is on one line.
    # A fenced or multi-line block is moved out. This matches
    # +RenderingInterface#block_context?+: Code prints as a fenced block when a
    # Text child has a newline (the language alone does not make it a block).
    KEEP_INLINE_CODE =
      lambda do |_boundary, node|
        block = node.children.any? { |c| c.instance_of?(AST::Text) && c.text.include?("\n") }
        block ? :hoist_after : :keep
      end

    class << self
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
        # inner link and keep its text.
        rules.add(parent: AST::Url, child: AST::Url, strategy: :unwrap)

        INLINE_CONTAINERS.each do |container|
          rules.add(parent: container, child: AST::Code, strategy: KEEP_INLINE_CODE)

          BLOCK_NODES.each do |block|
            next if container == block

            rules.add(parent: container, child: block, strategy: :hoist_after)
          end
        end

        rules
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
      collect_violations(ast, EMPTY_STACK, found)
      found
    end

    def freeze
      @rules.freeze
      super
    end

    private

    def collect_violations(element, ancestors, found)
      stack = ancestors + [element]
      element.children.each do |child|
        strategy, boundary = @rules.resolve(child, stack)
        strategy = strategy.call(boundary, child) if strategy.respond_to?(:call)
        unless strategy.nil? || strategy == :keep
          found << { parent: demodulize(boundary.class), child: demodulize(child.class), strategy: }
        end
        collect_violations(child, stack, found) if child.is_a?(AST::Element)
      end
    end

    def demodulize(klass)
      klass.name.split("::").last
    end
  end
end
