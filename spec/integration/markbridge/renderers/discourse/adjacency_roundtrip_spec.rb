# frozen_string_literal: true

# Puts two nodes next to each other on purpose and checks that the cooked
# HTML still says what the AST says. AdjacencyGenerator builds the cases,
# RoundTripChecker runs the checks. This spec runs a fixed sample of the
# inline pairs, every block pair and every case the known-bug list names;
# bin/fuzz-render runs all of them.
RSpec.describe "renderer adjacency round-trip" do
  sample_size = Integer(ENV.fetch("ADJACENCY_SAMPLE", "2000"))
  known_cases = RoundTripKnownBugs.named(:adjacency) + RoundTripKnownBugs.named(:adjacency_engine)
  cases =
    (
      AdjacencyGenerator.inline_sample(sample_size, seed: AdjacencyGenerator::DEFAULT_SAMPLE_SEED) +
        AdjacencyGenerator.block_cases + known_cases.filter_map { |id| AdjacencyGenerator.find(id) }
    ).uniq(&:id)
  cases_by_id = cases.to_h { |kase| [kase.id, kase] }

  it "names only cases the generator builds in the known bugs" do
    unknown = known_cases.reject { |id| AdjacencyGenerator.find(id) }

    expect(unknown).to eq([])
  end

  label = ->(id) { id }
  build = ->(id) { cases_by_id.fetch(id).document }

  context "when cooked with markdown-it", skip: MarkdownItCooker::SKIP_REASON do
    include_examples "round-trip cases", :adjacency, cases_by_id.keys, label:, build:
  end

  # The same cases through Discourse's own engine, per profile, see the
  # structure spec.
  context "when cooked with the Discourse engine", :discourse_engine do
    DiscourseEngineCooker::PROFILES.each_key do |profile|
      context "with the #{profile} profile" do
        cooker = DiscourseEngineCooker.profile(profile)

        include_examples "round-trip cases",
                         :adjacency_engine,
                         cases_by_id.keys,
                         label:,
                         build:,
                         checker: RoundTripChecker.new(features: cooker.features, cooker:)
      end
    end
  end
end
