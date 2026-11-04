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
  SEED_COUNT = Integer(ENV.fetch("STRUCTURE_SEEDS", "300"))
  STRUCTURE_SEEDS = ((1..SEED_COUNT).to_a + RoundTripKnownBugs.named(:structure)).uniq.sort.freeze

  context "when cooked with markdown-it", skip: MarkdownItCooker::SKIP_REASON do
    checker = RoundTripChecker.new

    it "lists only known bugs that cover a seed this spec runs" do
      unused = RoundTripKnownBugs.unused(:structure, STRUCTURE_SEEDS)

      expect(unused.map(&:reason)).to eq([])
    end

    STRUCTURE_SEEDS.each do |seed|
      reason = RoundTripKnownBugs.reason(:structure, seed)

      if reason
        it "does not round-trip seed #{seed}: #{reason}" do
          failures = checker.failures(AstGenerator.new(seed).document)

          expect(failures).not_to be_empty,
          "seed #{seed} round-trips now, remove it from the known bugs"
        end
      else
        it "round-trips seed #{seed}" do
          document = AstGenerator.new(seed).document

          expect(checker.failures(document)).to be_empty,
          -> { checker.explain(document, label: "seed #{seed}") }
        end
      end
    end
  end
end
