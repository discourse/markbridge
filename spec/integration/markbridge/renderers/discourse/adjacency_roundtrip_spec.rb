# frozen_string_literal: true

# Puts two nodes next to each other on purpose and checks that the cooked
# HTML still says what the AST says. AdjacencyGenerator builds the cases,
# RoundTripChecker runs the checks. This spec runs a fixed sample of the
# inline pairs, every block pair and every case the known-bug list names;
# bin/fuzz-render runs all of them.
RSpec.describe "renderer adjacency round-trip" do
  sample_size = Integer(ENV.fetch("ADJACENCY_SAMPLE", "2000"))
  cases =
    (
      AdjacencyGenerator.inline_sample(sample_size, seed: AdjacencyGenerator::DEFAULT_SAMPLE_SEED) +
        AdjacencyGenerator.block_cases +
        RoundTripKnownBugs.named(:adjacency).filter_map { |id| AdjacencyGenerator.find(id) }
    ).uniq(&:id)
  cases_by_id = cases.to_h { |kase| [kase.id, kase] }

  it "names only cases the generator builds in the known bugs" do
    unknown = RoundTripKnownBugs.named(:adjacency).reject { |id| AdjacencyGenerator.find(id) }

    expect(unknown).to eq([])
  end

  context "when cooked with markdown-it", skip: MarkdownItCooker::SKIP_REASON do
    include_examples "round-trip cases",
                     :adjacency,
                     cases_by_id.keys,
                     label: ->(id) { id },
                     build: ->(id) { cases_by_id.fetch(id).document }
  end
end
