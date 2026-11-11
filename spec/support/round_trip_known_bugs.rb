# frozen_string_literal: true

# The round-trip cases that fail today. A case on one of these lists is
# expected to fail; the specs fail when a listed case starts to pass, so a
# fix removes its entry in the same commit.
#
# An entry names its reason and the cases it covers. A case in the
# adjacency list is a case id (see AdjacencyGenerator) or a Regexp that
# matches ids; in the structure list it is a seed of AstGenerator, in the
# repair list a seed of BrokenAstGenerator. The
# specs run every case named outright, a Regexp only covers the cases a
# spec runs anyway.
module RoundTripKnownBugs
  Entry = Data.define(:reason, :cases)

  def self.entry(reason, cases:)
    Entry.new(reason:, cases:)
  end

  ADJACENCY = [].freeze

  STRUCTURE = [
    entry(
      "a nested list that ends with a table written as HTML, with another nested list after " \
        "it: the HTML block needs a blank line to end, and that makes the outer list loose",
      cases: [24_814],
    ),
  ].freeze

  # Seeds of BrokenAstGenerator, checked with NormalizerRepairChecker.
  REPAIR = [
    entry(
      "a block that leaves bold inside a color or an inline spoiler lands in the color or the " \
        "spoiler, which are no inline containers for the normalizer; in a list item the list " \
        "cooks loose then",
      cases: [929, 1578],
    ),
  ].freeze

  # Seeds of AstGenerator, written as HTML and checked with
  # HtmlRoundTripChecker.
  HTML = [].freeze

  # The same cases cooked with the Discourse engine (any profile; the
  # reason names the profile when it matters).
  ADJACENCY_ENGINE = [].freeze

  STRUCTURE_ENGINE = [].freeze

  LISTS = {
    adjacency: ADJACENCY,
    structure: STRUCTURE,
    adjacency_engine: ADJACENCY_ENGINE,
    structure_engine: STRUCTURE_ENGINE,
    repair: REPAIR,
    html: HTML,
  }.freeze

  # @param list [Symbol] a key of LISTS
  # @param id [String, Integer] a case id or a seed
  # @return [String, nil] the reason the case is expected to fail
  def self.reason(list, id)
    entries(list).find { |entry| covers?(entry, id) }&.reason
  end

  # The cases the lists name outright, so a spec can make sure to run them.
  # @return [Array<String, Integer>]
  def self.named(list)
    entries(list).flat_map { |entry| entry.cases.reject { |kase| kase.is_a?(Regexp) } }.uniq
  end

  # The entries that cover none of +ids+. Such an entry names a case that
  # no longer exists or a pattern that matches nothing, and both are a
  # mistake in the list.
  # @return [Array<Entry>]
  def self.unused(list, ids)
    entries(list).reject { |entry| ids.any? { |id| covers?(entry, id) } }
  end

  def self.entries(list)
    LISTS.fetch(list)
  end

  def self.covers?(entry, id)
    entry.cases.any? do |kase|
      kase.is_a?(Regexp) ? id.is_a?(String) && kase.match?(id) : kase == id
    end
  end

  private_class_method :entries, :covers?
end
