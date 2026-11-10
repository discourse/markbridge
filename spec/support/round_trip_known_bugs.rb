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

  ADJACENCY = [].freeze

  # An upload in html_mode is a Markdown island, a <div> with blank lines.
  # Inside an inline element in a paragraph, `<p><del><div>`, the HTML
  # parser ends the paragraph at the <div> and the inline element is left
  # empty in front of it. The wrapper can be any inline element that is
  # written as an HTML tag there (del, sub, s, ...).
  UPLOAD_IN_INLINE_HTML =
    "an upload inside an inline element inside a paragraph, in a table written as HTML: " \
      "the island's <div> ends the <p>, and the inline element stays empty in front of it"

  STRUCTURE = [entry(UPLOAD_IN_INLINE_HTML, cases: [1136, 4485])].freeze

  # The same cases cooked with the Discourse engine (any profile; the
  # reason names the profile when it matters).
  ADJACENCY_ENGINE = [].freeze

  STRUCTURE_ENGINE = [entry(UPLOAD_IN_INLINE_HTML, cases: [1136])].freeze

  LISTS = {
    adjacency: ADJACENCY,
    structure: STRUCTURE,
    adjacency_engine: ADJACENCY_ENGINE,
    structure_engine: STRUCTURE_ENGINE,
  }.freeze

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
