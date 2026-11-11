# frozen_string_literal: true

# Reads random BBCode (BBCodeGenerator) two ways and compares the
# Markdown: with the BBCode parser, and with s9e\TextFormatter and the
# TextFormatter parser (S9eDifferentialChecker). The inputs have the
# mistakes people make, a closing tag that is missing or in the wrong
# place, and the two parsers have to end the same elements at the same
# place.
#
# s9e_reference_spec.rb compares with s9e too, but with the inputs of
# its own tests, which are mostly well-formed.
#
# The examples need PHP and a checkout of s9e (`bin/s9e-setup`) and
# skip without them. `S9E_SEEDS=1000 bundle exec rspec <file>` runs
# more seeds, and `bin/fuzz-parse --only s9e` runs them outside RSpec.
RSpec.describe "BBCode read like s9e reads it", skip: S9eParser::SKIP_REASON do
  seed_count = Integer(ENV.fetch("S9E_SEEDS", "300"))
  checker = S9eDifferentialChecker.new
  seeds = ((1..seed_count).to_a + S9eDifferentialChecker::KNOWN.keys).uniq.sort

  seeds.each do |seed|
    reason = S9eDifferentialChecker::KNOWN[seed]

    if reason
      it "differs for seed #{seed}: #{reason}" do
        expect(checker.seed_difference(seed)).not_to be_nil,
        "seed #{seed} reads the same now, remove it from S9eDifferentialChecker::KNOWN"
      end
    else
      it "reads seed #{seed} like s9e" do
        difference = checker.seed_difference(seed)

        expect(difference).to be_nil, -> { difference }
      end
    end
  end
end
