# frozen_string_literal: true

# The round-trip cases that fail today. A case on one of these lists is
# expected to fail; the specs fail when a listed case starts to pass, so a
# fix removes its entry in the same commit.
#
# An entry names its reason and the cases it covers. A case in the
# adjacency list is a case id (see AdjacencyGenerator) or a Regexp that
# matches ids; in the structure list it is a seed of AstGenerator. The
# specs run every case named outright, a Regexp only covers the cases a
# spec runs anyway.
module RoundTripKnownBugs
  Entry = Data.define(:reason, :cases)

  def self.entry(reason, cases:)
    Entry.new(reason:, cases:)
  end

  ADJACENCY = [
    entry(
      "in html_mode a paragraph next to other content has no <p>, a blank line in text or block code ends the HTML block, an empty emphasis or quote is written, and a spoiler is a <details> block",
      cases: [
        "blocks/cell/ol+empty+ol",
        "blocks/cell/ol+empty+ul",
        "blocks/cell/ul+empty+ol",
        "blocks/cell/ul+empty+ul",
        %r{\Ahtml-cell/.*spoiler},
      ],
    ),
  ].freeze

  STRUCTURE = [
    entry(
      "in html_mode a paragraph next to other content has no <p>, a blank line in text or block code ends the HTML block, an empty emphasis or quote is written, and a spoiler is a <details> block",
      cases: [
        3,
        7,
        23,
        52,
        66,
        73,
        86,
        112,
        117,
        122,
        133,
        135,
        139,
        145,
        155,
        192,
        196,
        202,
        204,
        210,
        211,
        213,
        234,
        238,
        242,
        250,
        251,
      ],
    ),
  ].freeze

  LISTS = { adjacency: ADJACENCY, structure: STRUCTURE }.freeze

  # @param list [Symbol] :adjacency or :structure
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
