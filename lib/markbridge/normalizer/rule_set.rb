# frozen_string_literal: true

module Markbridge
  class Normalizer
    # Maps a node and its ancestor stack to a strategy.
    #
    # Matching is exact-class (equivalent to +instance_of?+): rules are
    # keyed by +Class+ and looked up via +node.class+, so an anonymous
    # +Class.new(AST::Element)+ or any future subclass never accidentally
    # matches a rule written for the base class. Registering a rule for a
    # +(parent, child)+ pair that already has one replaces it, so later
    # layers (Discourse, a consumer's +#rule+) override earlier ones.
    class RuleSet
      NO_MATCH = [nil, nil].freeze

      def initialize
        @by_parent = {} # parent_class => { child_class => strategy }
        @child_classes = Set.new
      end

      # Register (or replace) a rule.
      #
      # @param parent [Class] ancestor AST class
      # @param child [Class] contained AST class
      # @param strategy [Symbol, #call] a strategy symbol or callable
      # @return [self]
      def add(parent:, child:, strategy:)
        validate_strategy!(strategy)
        (@by_parent[parent] ||= {})[child] = strategy
        @child_classes << child
        self
      end

      # Resolve the strategy for +child+ given its ancestor stack (root
      # first). Returns +[strategy, boundary]+ where +boundary+ is the
      # *outermost* ancestor whose class has a rule for +child+'s class, or
      # {NO_MATCH} (+[nil, nil]+) when nothing matches.
      #
      # @param child [AST::Node]
      # @param ancestors [Array<AST::Element>] root-first ancestor stack
      # @return [Array(Object, AST::Element), Array(nil, nil)]
      def resolve(child, ancestors)
        child_class = child.class
        # Skip the ancestor scan for a class no rule targets (most nodes, for
        # example plain text). The scan below returns the same result for such
        # a class, so this only saves work.
        return NO_MATCH unless @child_classes.include?(child_class)

        scan_ancestors(child_class, ancestors)
      end

      # Freeze so a shared instance raises if something tries to change it.
      # Freezing +@by_parent+ and its inner hashes is enough: {#add} writes
      # there before it touches +@child_classes+, so a frozen instance raises
      # on the +@by_parent+ write first. +@child_classes+ is never reached, so
      # it does not need freezing.
      def freeze
        @by_parent.each_value(&:freeze)
        @by_parent.freeze
        super
      end

      private

      # The ancestor scan behind {#resolve}: the outermost matching ancestor
      # wins. It is split from the skip check in {#resolve} so the scan can be
      # tested on its own.
      def scan_ancestors(child_class, ancestors)
        ancestors.each do |ancestor|
          strategies = @by_parent[ancestor.class]
          next unless strategies

          strategy = strategies[child_class]
          return strategy, ancestor if strategy
        end
        NO_MATCH
      end

      def validate_strategy!(strategy)
        return if strategy.respond_to?(:call)
        return if STRATEGIES.include?(strategy)

        raise ArgumentError,
              "unknown strategy #{strategy.inspect} " \
                "(expected one of #{STRATEGIES.inspect} or a callable)"
      end
    end
  end
end
