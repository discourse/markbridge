# frozen_string_literal: true

# Builds trees that break the rules of the default normalizer
# (BrokenAstGenerator: a block in bold, a list in a link, a heading in
# a heading), lets the normalizer repair them and checks the result
# with NormalizerRepairChecker: no two words are one word afterwards,
# nothing is lost, a second run changes nothing, and the repaired tree
# round-trips through the renderer and markdown-it.
#
# The structure round-trip cannot find a mistake in a repair: its
# generator stays inside what the normalizer accepts.
#
# `REPAIR_SEEDS=3000 bundle exec rspec <file>` runs more seeds, and
# `bin/fuzz-render --only repairs` runs them outside RSpec.
RSpec.describe "normalizer repair", skip: MarkdownItCooker::SKIP_REASON do
  seed_count = Integer(ENV.fetch("REPAIR_SEEDS", "300"))
  seeds = ((1..seed_count).to_a + RoundTripKnownBugs.named(:repair)).uniq.sort

  include_examples "round-trip cases",
                   :repair,
                   seeds,
                   label: ->(seed) { "seed #{seed}" },
                   build: ->(seed) { BrokenAstGenerator.new(seed).document },
                   checker: NormalizerRepairChecker.new
end
