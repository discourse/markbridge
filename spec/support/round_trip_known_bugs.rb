# frozen_string_literal: true

require_relative "adjacency_generator"

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

  # Neighbors that do not glue to a bare URL: whitespace, a line break,
  # and a `(` in front of it.
  NOT_GLUED = %w[
    text(space)
    text(dot-space)
    text(nbsp)
    markdown(space)
    markdown(dot-space)
    markdown(nbsp)
    break
  ].freeze

  RELATIVE_BARE_URL_CASES =
    (AdjacencyGenerator::INLINE_POSITIONS.keys - ["label"])
      .flat_map do |position|
        NOT_GLUED.flat_map do |neighbor|
          ["#{position}/#{neighbor}+relative", "#{position}/relative+#{neighbor}"]
        end << "#{position}/text(()+relative"
      end
      .freeze

  SPOILER_COLON_CASES =
    %w[item quote]
      .product(%w[break empty])
      .map { |position, left| "#{position}/#{left}+spoiler(:)" }
      .freeze

  TWO_LISTS_IN_AN_ITEM_CASES =
    AdjacencyGenerator::LISTS
      .product(AdjacencyGenerator::BETWEEN.keys)
      .map { |list, between| "blocks/item/#{list}+#{between}+#{list}" }
      .freeze

  ADJACENCY = [
    entry(
      "a bare link with a relative href renders as its plain text when nothing is glued to it, " \
        "and plain text does not link",
      cases: RELATIVE_BARE_URL_CASES,
    ),
    entry(
      "two lists of the same kind in one list item are kept apart by a comment between blank lines, " \
        "which makes the item loose",
      cases: TWO_LISTS_IN_AN_ITEM_CASES,
    ),
    entry(
      "a spoiler whose content starts with `:`, at the start of a line with nothing after it, " \
        "reads as a link reference definition and disappears",
      cases: SPOILER_COLON_CASES,
    ),
  ].freeze

  STRUCTURE = [
    entry(
      "two line breaks in a row inside a list item (the first one may end an inline wrapper) " \
        "become a blank line, which makes the list loose",
      cases: [
        524,
        554,
        1104,
        1266,
        1423,
        1560,
        1594,
        1920,
        1921,
        1982,
        2087,
        2229,
        2263,
        2272,
        2280,
        2485,
        2494,
        2574,
        2582,
        2696,
      ],
    ),
    entry(
      "whitespace-only text after a block is written as leading spaces of the next line, " \
        "which pulls the paragraph after it into the block",
      cases: [1841],
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
