# frozen_string_literal: true

# Puts two nodes next to each other on purpose and checks that the cooked
# HTML still says what the AST says. AdjacencyGenerator builds the cases,
# RoundTripChecker runs the checks. This spec runs a fixed sample of the
# inline pairs, every block pair and every case the known-bug list names;
# bin/fuzz-render runs all of them.
RSpec.describe "renderer adjacency round-trip" do
  ADJACENCY_SAMPLE_SIZE = Integer(ENV.fetch("ADJACENCY_SAMPLE", "2000"))
  ADJACENCY_SAMPLE_SEED = 1

  ADJACENCY_CASES =
    (
      AdjacencyGenerator.inline_sample(ADJACENCY_SAMPLE_SIZE, seed: ADJACENCY_SAMPLE_SEED) +
        AdjacencyGenerator.block_cases +
        RoundTripKnownBugs.named(:adjacency).filter_map { |id| AdjacencyGenerator.find(id) }
    ).uniq(&:id).freeze

  it "names only cases the generator builds in the known bugs" do
    unknown = RoundTripKnownBugs.named(:adjacency).reject { |id| AdjacencyGenerator.find(id) }

    expect(unknown).to eq([])
  end

  context "when cooked with markdown-it", skip: MarkdownItCooker::SKIP_REASON do
    checker = RoundTripChecker.new

    it "lists only known bugs that cover a case this spec runs" do
      unused = RoundTripKnownBugs.unused(:adjacency, ADJACENCY_CASES.map(&:id))

      expect(unused.map(&:reason)).to eq([])
    end

    ADJACENCY_CASES.each do |kase|
      reason = RoundTripKnownBugs.reason(:adjacency, kase.id)

      if reason
        it "does not round-trip #{kase.id}: #{reason}" do
          failures = checker.failures(kase.document)

          expect(failures).not_to be_empty,
          "#{kase.id} round-trips now, remove it from the known bugs"
        end
      else
        it "round-trips #{kase.id}" do
          document = kase.document

          expect(checker.failures(document)).to be_empty,
          -> { checker.explain(document, label: kase.id) }
        end
      end
    end
  end
end
