# frozen_string_literal: true

require_relative "normalizer/rule_set"
require_relative "normalizer/report"
require_relative "normalizer/text_projection"
require_relative "normalizer/walker"
require_relative "normalizer/layers"

module Markbridge
  # Enforces target-format nesting rules on an AST between parse and render.
  #
  # Real markup nests elements in ways Markdown can't express (a link inside
  # a link, an image inside a link, a block inside a link label). The
  # renderer's tags stay simple string emitters; this pass, one level up,
  # rewrites the tree so the renderer is only ever handed something legal.
  #
  # Two rule layers: a CommonMark layer of objective legality and a
  # Discourse layer of renderer policy on top. Each violation resolves to a
  # strategy — +:keep+, +:hoist_after+, +:unwrap+, +:textify+, +:drop+, or a
  # callable escape hatch — applied by the {Walker}.
  #
  # @example Default (CommonMark + Discourse), reused across conversions
  #   Markbridge::Normalizer.shared_for(:discourse)
  #
  # @example Customized for a consumer
  #   n = Markbridge::Normalizer.for(:discourse)
  #   n.rule(parent: AST::Url, child: AST::Mention, strategy: :textify)
  #   Markbridge.convert(input, format: :bbcode, normalize: n)
  #
  # @example Lint a tree without mutating it
  #   Markbridge::Normalizer.common_mark.violations(ast) # => [...]
  class Normalizer
    # The built-in strategy symbols a rule may resolve to.
    STRATEGIES = %i[keep hoist_after unwrap textify drop].freeze

    EMPTY_STACK = [].freeze
    private_constant :EMPTY_STACK

    class << self
      # A fresh, customizable normalizer for a target format.
      # @param target [Symbol] currently only +:discourse+
      # @return [Normalizer]
      def for(target)
        new(layer_for(target))
      end

      # A fresh normalizer carrying only the CommonMark layer (no Discourse
      # policy) — the objective-legality rules, handy for validation.
      # @return [Normalizer]
      def common_mark
        new(Layers.common_mark)
      end

      # A memoized, deep-frozen normalizer for the hot path — its rule
      # tables are built once per process. Safe to share across conversions
      # and threads because +#normalize+/+#violations+ keep no per-call
      # state on +self+.
      #
      # @param target [Symbol]
      # @return [Normalizer] the same frozen instance on every call
      def shared_for(target)
        (@shared ||= {})[target] ||= self.for(target).freeze
      end

      private

      def layer_for(target)
        case target
        when :discourse
          Layers.discourse
        else
          raise ArgumentError, "unknown normalizer target #{target.inspect} (expected :discourse)"
        end
      end
    end

    # @param rule_set [RuleSet]
    def initialize(rule_set)
      @rules = rule_set
    end

    # Add or override a rule. Chainable. Raises on a frozen ({shared_for})
    # instance — build a fresh one via {.for}.
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
    # @return [Array<Hash>] a report of what changed (empty when nothing
    #   did), one +{parent:, child:, strategy:, count:}+ row per distinct
    #   transformation.
    def normalize(ast)
      report = Report.new
      Walker.new(@rules, report).call(ast)
      report.to_a
    end

    # Report would-be violations of +ast+ without mutating it.
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
