# frozen_string_literal: true

module Markbridge
  class Normalizer
    # Tally of the transformations a single {Normalizer#normalize} pass
    # applied. Held as a local per call (never on the Normalizer), so a
    # frozen shared instance stays reusable and thread-safe.
    class Report
      # The name of an AST class without its modules, as the report and
      # {Normalizer#violations} show it. A class without a name, from
      # Class.new, is shown as the nearest ancestor that has one.
      #
      # @param klass [Class]
      # @return [String]
      def self.short_name(klass)
        klass = klass.superclass until klass.name
        klass.name.split("::").last
      end

      def initialize
        @counts = Hash.new(0)
      end

      # @param parent_class [Class] the offending ancestor's class
      # @param child_class [Class] the moved/removed node's class
      # @param strategy [Symbol] the strategy actually applied
      def record(parent_class, child_class, strategy)
        @counts[[Report.short_name(parent_class), Report.short_name(child_class), strategy]] += 1
      end

      # @return [Boolean]
      def empty?
        @counts.empty?
      end

      # One +{parent:, child:, strategy:, count:}+ row per distinct
      # transformation, e.g.
      # +{parent: "Url", child: "Image", strategy: :hoist_after, count: 3}+.
      #
      # @return [Array<Hash>]
      def to_a
        @counts.map { |(parent, child, strategy), count| { parent:, child:, strategy:, count: } }
      end
    end
  end
end
