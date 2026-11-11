# frozen_string_literal: true

# Converts short pieces of markup that are repeated many times, and
# checks that the time grows with the length of the input and not with
# its square (see RunTimeChecker). A normal post never shows such a
# problem: the cases here are a line of 8,000 `[[a ` with nothing that
# closes them, or a table in a table twenty times.
#
# This runs a part of the cases, `bin/fuzz-parse --only time` runs all
# of them. A case that is slow today is in RunTimeChecker::KNOWN with
# the reason and is left out here.
#
# Not with COVERAGE=1: the coverage makes the time of a run depend on
# what else was loaded, and mutant picks its tests from that run, so it
# does not pick these. Not on JRuby and TruffleRuby either, whose
# compilers make the second run of a conversion faster than the first
# for reasons that have nothing to do with the input.
RSpec.describe "run time of a conversion",
               skip:
                 if ENV["COVERAGE"]
                   "time is not measured with coverage"
                 elsif RUBY_ENGINE != "ruby"
                   "time is measured on CRuby only"
                 end do
  RunTimeChecker
    .sample(11)
    .each do |kase|
      it "grows with the size of the input for #{kase.id}" do
        growth = RunTimeChecker.slow(kase)

        expect(growth).to be_nil,
        -> do
          "an input #{RunTimeChecker::FACTOR} times as long takes #{growth.round(1)} times " \
            "as long, the limit is #{RunTimeChecker::LIMIT}"
        end
      end
    end
end
