# frozen_string_literal: true

require_relative "round_trip_checker"
require_relative "round_trip_known_bugs"

# The shape the structure and the adjacency round-trip specs share: one
# example per case. A case on the known-bug list has to keep failing,
# every other case has to round-trip, and one that does not explains
# itself with the shrunk AST, its Markdown and the cooked HTML.
#
# +list+ is the known-bug list (:structure or :adjacency), +cases+ the
# ids the spec runs (seeds or case ids), +label+ turns an id into the
# name of its example and +build+ into its document.
RSpec.shared_examples "round-trip cases" do |list, cases, label:, build:|
  checker = RoundTripChecker.new

  it "lists only known bugs that cover a case this spec runs" do
    unused = RoundTripKnownBugs.unused(list, cases)

    expect(unused.map(&:reason)).to eq([])
  end

  cases.each do |id|
    reason = RoundTripKnownBugs.reason(list, id)

    if reason
      it "does not round-trip #{label.call(id)}: #{reason}" do
        failures = checker.failures(build.call(id))

        expect(failures).not_to be_empty,
        "#{label.call(id)} round-trips now, remove it from the known bugs"
      end
    else
      it "round-trips #{label.call(id)}" do
        document = build.call(id)

        expect(checker.failures(document)).to be_empty,
        -> { checker.explain(document, label: label.call(id)) }
      end
    end
  end
end
