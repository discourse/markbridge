# frozen_string_literal: true

module Markbridge
  class Normalizer
    # Tally of the transformations a single {Normalizer#normalize} pass
    # applied. Held as a local per call (never on the Normalizer), so a
    # frozen shared instance stays reusable and thread-safe.
    class Report
      def initialize
        @counts = Hash.new(0)
      end

      # @param parent_class [Class] the offending ancestor's class
      # @param child_class [Class] the moved/removed node's class
      # @param strategy [Symbol] the strategy actually applied
      def record(parent_class, child_class, strategy)
        @counts[[demodulize(parent_class), demodulize(child_class), strategy]] += 1
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

      private

      def demodulize(klass)
        klass.name.split("::").last
      end
    end
  end
end
