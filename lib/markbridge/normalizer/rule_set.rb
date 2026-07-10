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
        # Fast path: skip the ancestor scan entirely for a class no rule
        # targets (the common case — plain text). Pure optimization; the scan
        # below returns the same result for a non-candidate class.
        return NO_MATCH unless @child_classes.include?(child_class)

        scan_ancestors(child_class, ancestors)
      end

      # Deep-freeze so a shared instance fails loudly on mutation. Freezing
      # +@by_parent+ and its inner hashes is enough: {#add} writes there
      # before it ever touches +@child_classes+, so a frozen registry always
      # raises on the +@by_parent+ write first — +@child_classes+ can never be
      # reached to be mutated, and so does not need freezing.
      def freeze
        @by_parent.each_value(&:freeze)
        @by_parent.freeze
        super
      end

      private

      # The ancestor scan behind {#resolve}: outermost matching ancestor
      # wins. Split out from the fast-path guard so its behaviour stays under
      # test while the guard (a pure optimization) can be ignored.
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
