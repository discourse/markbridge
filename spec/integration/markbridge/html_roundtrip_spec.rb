# frozen_string_literal: true

# The round trip that starts with HTML. The trees of AstGenerator are
# written as HTML in several styles (AstHtmlWriter), the HTML is
# converted, the Markdown is cooked, and the cooked HTML has to show
# the structure, the text and the links of the HTML it started from
# (HtmlRoundTripChecker).
#
# The CommonMark round trip does the same with the examples of the
# spec, which are HTML a Markdown parser wrote. The HTML here is what
# other software writes: paragraphs as `<div>`, `<b>` for `<strong>`,
# a `<section>` around everything, line breaks between the tags.
#
# `HTML_SEEDS=3000 bundle exec rspec <file>` runs more seeds, and
# `bin/fuzz-render --only html` runs them outside RSpec.
RSpec.describe "HTML round-trip", skip: MarkdownItCooker::SKIP_REASON do
  seed_count = Integer(ENV.fetch("HTML_SEEDS", "300"))
  seeds = ((1..seed_count).to_a + RoundTripKnownBugs.named(:html)).uniq.sort

  include_examples "round-trip cases",
                   :html,
                   seeds,
                   label: ->(seed) { "seed #{seed}" },
                   build: ->(seed) { AstHtmlWriter.lower(AstGenerator.new(seed).document) },
                   checker: HtmlRoundTripChecker.new
end
