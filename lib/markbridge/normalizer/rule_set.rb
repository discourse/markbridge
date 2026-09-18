# frozen_string_literal: true

module Markbridge
  class Normalizer
    # Maps a node and its ancestor stack to a strategy.
    #
    # Rules are keyed by +Class+ on both sides, and matching follows the
    # class ancestry: a rule registered for a base class also applies to
    # its subclasses, for the parent and for the child. Only classes
    # inside the +AST::Node+ hierarchy take part; the walk never reaches
    # +Object+, so a rule keyed on a class outside the AST never matches.
    #
    # Precedence, in this order:
    # 1. Stack position — the outermost ancestor in the stack with any
    #    matching rule wins.
    # 2. Child class specificity — at that ancestor, a rule keyed on the
    #    node's own class beats a rule keyed on a superclass.
    # 3. Parent class specificity — then a rule keyed on the ancestor's
    #    own class beats a rule keyed on a superclass.
    #
    # A rule registered for the exact +(parent, child)+ pair therefore
    # always overrides an inherited one. Registering a rule for a pair
    # that already has one replaces it, so later layers (Discourse, a
    # consumer's +#rule+) override earlier ones.
    class RuleSet
      NO_MATCH = [nil, nil].freeze

      # Shared "no rule targets this class" marker, so the cache entry for
      # a rule-less class costs no allocation.
      EMPTY_CANDIDATES = [].freeze

      def initialize
        @by_parent = {} # parent_class => { child_class => strategy }
        @child_classes = Set.new
        # @candidates_cache stays unset (nil) until #freeze fills it.
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
      # *outermost* ancestor with a rule that matches +child+'s class, or
      # {NO_MATCH} (+[nil, nil]+) when nothing matches.
      #
      # +walk_cache+ caches the child-rule candidates per class. The caller owns
      # it and should reuse one Hash for a whole tree walk, so each
      # distinct class is analyzed at most once per walk. Keeping the
      # cache outside the RuleSet leaves a frozen shared instance free of
      # per-call state. The cache read is a single Hash lookup because this
      # method runs for every node in the tree.
      #
      # @param child [AST::Node]
      # @param ancestors [Array<AST::Element>] root-first ancestor stack
      # @param walk_cache [Hash{Class => Array<Class>}] per-walk cache owned by
      #   the caller
      # @return [Array(Object, AST::Element), Array(nil, nil)]
      def resolve(child, ancestors, walk_cache)
        klass = child.class
        # A frozen rule set carries a prebuilt candidates cache (see
        # #freeze); the walk cache is only needed for classes defined after the
        # freeze and for mutable rule sets.
        frozen_cache = @candidates_cache
        candidates =
          (frozen_cache && frozen_cache[klass]) || (walk_cache[klass] ||= child_candidates(klass))
        # Skip the ancestor scan for a class no rule targets (most nodes, for
        # example plain text). The scan below returns the same result for such
        # a class, so this only saves work.
        return NO_MATCH if candidates.empty?

        scan_ancestors(candidates, ancestors)
      end

      # Freeze so a shared instance raises if something tries to change it.
      # Freezing +@by_parent+ and its inner hashes is enough: {#add} writes
      # there before it touches +@child_classes+, so a frozen instance raises
      # on the +@by_parent+ write first. +@child_classes+ is never reached, so
      # it does not need freezing.
      #
      # Freezing also precomputes the child-rule candidates for every AST
      # class known at this point (+AST::Node.descendants+ is boot-time
      # state), so {#resolve} on a frozen rule set answers with one Hash
      # lookup instead of going through the per-walk cache. The rules can
      # not change anymore, so the cache can never go stale; classes
      # defined after the freeze fall back to the walk cache. The +||=+ keeps a
      # second freeze from writing to the then-frozen instance. Like
      # +@child_classes+, the cache Hash stays unfrozen — nothing writes
      # to it after this point.
      def freeze
        @candidates_cache ||=
          AST::Node.descendants.to_h { |klass| [klass, child_candidates(klass)] }
        @by_parent.each_value(&:freeze)
        @by_parent.freeze
        super
      end

      private

      # The ancestor scan behind {#resolve}: the outermost ancestor with any
      # matching rule wins (precedence 1). {#best_rule} applies the class
      # specificity order within one ancestor.
      def scan_ancestors(candidates, ancestors)
        ancestors.each do |ancestor|
          strategy = best_rule(candidates, ancestor.class)
          return strategy, ancestor if strategy
        end
        NO_MATCH
      end

      # The most specific rule at one ancestor: try each child candidate
      # (the node's own class first — precedence 2), and for each walk the
      # ancestor's class chain inside the AST (its own class first —
      # precedence 3). An ancestor whose class is outside the AST has no
      # chain and can never match. (+Module#<=+ is nil for an unrelated
      # class, so the ternary — not an inverted guard — is the correct
      # check here.)
      def best_rule(candidates, ancestor_class)
        chain = ancestor_class <= AST::Node ? ancestor_class.ast_chain : EMPTY_CANDIDATES
        candidates.each do |child_class|
          chain.each do |parent_class|
            strategies = @by_parent[parent_class]
            strategy = strategies[child_class] if strategies
            return strategy if strategy
          end
        end
        nil
      end

      # The classes in +klass+'s AST chain that at least one rule targets
      # as a child, most specific class first (empty for most classes). A
      # fresh walk cache sees every class once per document, so this allocates
      # nothing unless there is a match. A class outside the AST has no
      # chain and no candidates (+Module#<=+ is nil for an unrelated
      # class, so the ternary — not an inverted guard — is the correct
      # check here).
      def child_candidates(klass)
        chain = klass <= AST::Node ? klass.ast_chain : EMPTY_CANDIDATES
        candidates = nil
        chain.each { |current| (candidates ||= []) << current if @child_classes.include?(current) }
        candidates || EMPTY_CANDIDATES
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
