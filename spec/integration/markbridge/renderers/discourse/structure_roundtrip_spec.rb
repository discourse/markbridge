# frozen_string_literal: true

# Builds nested ASTs from a seeded generator, renders them, cooks the
# Markdown and compares the cooked HTML with the AST. Asserting on the
# Markdown string alone lets a wrong indentation pass unnoticed: the
# string still looks plausible while CommonMark reads a code fence as
# indented code. The AST says "a list item at depth 3 holds a code
# block", so the cooked DOM has to show an li at depth 3 with a pre
# inside, and the code text has to be the code. RoundTripChecker runs
# that check and three more.
#
# A failing seed is shrunk to the few nodes that still fail, and the
# report shows the AST, the Markdown and the cooked HTML.
RSpec.describe "renderer structure round-trip" do
  seed_count = Integer(ENV.fetch("STRUCTURE_SEEDS", "300"))
  seeds = ((1..seed_count).to_a + RoundTripKnownBugs.named(:structure)).uniq.sort

  context "when cooked with markdown-it", skip: MarkdownItCooker::SKIP_REASON do
    include_examples "round-trip cases",
                     :structure,
                     seeds,
                     label: ->(seed) { "seed #{seed}" },
                     build: ->(seed) { AstGenerator.new(seed).document }
  end
end
