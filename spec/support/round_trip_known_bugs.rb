# frozen_string_literal: true

# The round-trip cases that fail today. A case on one of these lists is
# expected to fail; the specs fail when a listed case starts to pass, so a
# fix removes its entry in the same commit. The lists are empty right now.
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

  ADJACENCY = [].freeze

  STRUCTURE = [].freeze

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
