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
#
# The same seeds run through Discourse's own engine where it is built,
# once per profile of DiscourseEngineCooker, with the renderer features
# of that profile: there the BBCode of the plugins cooks, and the plain
# forms of a site without them cook too. Those runs also get attributed
# quotes, which plain markdown-it cannot read (see AstGenerator).
RSpec.describe "renderer structure round-trip" do
  seed_count = Integer(ENV.fetch("STRUCTURE_SEEDS", "300"))
  label = ->(seed) { "seed #{seed}" }

  context "when cooked with markdown-it", skip: MarkdownItCooker::SKIP_REASON do
    seeds = ((1..seed_count).to_a + RoundTripKnownBugs.named(:structure)).uniq.sort
    build = ->(seed) { AstGenerator.new(seed).document }

    include_examples "round-trip cases", :structure, seeds, label:, build:
  end

  context "when cooked with the Discourse engine", :discourse_engine do
    seeds = ((1..seed_count).to_a + RoundTripKnownBugs.named(:structure_engine)).uniq.sort
    build = ->(seed) { AstGenerator.new(seed, attributed_quotes: true).document }

    DiscourseEngineCooker::PROFILES.each_key do |profile|
      context "with the #{profile} profile" do
        cooker = DiscourseEngineCooker.profile(profile)

        include_examples "round-trip cases",
                         :structure_engine,
                         seeds,
                         label:,
                         build:,
                         checker: RoundTripChecker.new(features: cooker.features, cooker:)
      end
    end
  end
end
