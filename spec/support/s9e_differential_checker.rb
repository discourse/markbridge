# frozen_string_literal: true

require_relative "s9e_parser"
require_relative "bbcode_generator"

# Compares how Markbridge reads BBCode with how s9e\TextFormatter reads
# it. The same text goes two ways:
#
# - the BBCode parser of Markbridge reads it
# - s9e parses it to the XML it would store, and the TextFormatter
#   parser of Markbridge reads that XML
#
# Both trees are rendered, and the Markdown has to be the same. Where a
# closing tag is missing or in the wrong place, the two parsers have to
# end the same elements at the same place for that.
#
#   checker = S9eDifferentialChecker.new
#   checker.difference(["[quote]", "[*]", "x", "[/quote]"])  # => nil or a report
#
# An input is a list of tokens (see BBCodeGenerator), so +shrink+ can
# take tokens away as long as the two sides still differ.
class S9eDifferentialChecker
  # Seeds of BBCodeGenerator whose inputs differ today, with the reason.
  # The spec fails when one of them reads the same, so a fix removes
  # its entry.
  KNOWN = {
    27 =>
      "the closing tag of a list that the end of a quote has ended: Markbridge drops it, s9e " \
        "keeps it as text here (and drops it in other places)",
    611 =>
      "the closing tag of an aligned block that the end of a quote has ended: Markbridge " \
        "drops it, s9e keeps it as text",
    853 =>
      "a size that is open in the last item when the list ends: s9e opens it again behind " \
        "the list, Markbridge ends it with the list",
  }.freeze

  # With the BBCode plugin on, so a color, a size and an aligned block
  # are written with their tags and show where they start and end.
  def initialize
    @renderer = Markbridge.discourse_renderer(features: { bbcode: true }, sizes: ->(size) { size })
  end

  # @param seed [Integer]
  # @return [String, nil] the report for the input of the seed when the
  #   two sides differ and are not meant to (see
  #   BBCodeGenerator.intended_difference)
  def seed_difference(seed)
    tokens = BBCodeGenerator.new(seed).tokens
    return if BBCodeGenerator.intended_difference(tokens)
    return unless difference(tokens)

    small = shrink(tokens)
    "seed #{seed}, shrunk from #{tokens.size} to #{small.size} tokens\n\n#{difference(small)}"
  end

  # @param tokens [Array<String>]
  # @return [String, nil] the two Markdowns when they differ
  def difference(tokens)
    input = tokens.join
    xml = S9eParser.parse(input)
    ours = markdown { Markbridge.bbcode_to_markdown(input, renderer: @renderer) }
    theirs = markdown { Markbridge.text_formatter_xml_to_markdown(xml, renderer: @renderer) }
    return if ours == theirs

    [
      "BBCode:",
      input,
      "",
      "s9e XML:",
      xml,
      "",
      "Markdown from the BBCode:",
      ours,
      "",
      "Markdown from the XML:",
      theirs,
    ].join("\n")
  end

  # Takes tokens away as long as the two sides still differ, and as
  # long as the input stays of the same kind: an input that should be
  # read the same way must not shrink to one that is read differently
  # on purpose (see BBCodeGenerator.intended_difference).
  #
  # @param tokens [Array<String>] an input that differs
  # @return [Array<String>] a shorter input that still differs
  def shrink(tokens)
    tokens = tokens.dup
    kind = BBCodeGenerator.intended_difference(tokens)
    loop do
      index =
        tokens.each_index.find do |i|
          candidate = tokens[0...i] + tokens[(i + 1)..]
          BBCodeGenerator.intended_difference(candidate) == kind && difference(candidate)
        end
      break unless index

      tokens.delete_at(index)
    end
    tokens
  end

  # The tokens with every text reduced to a letter, so two inputs that
  # differ for the same reason are one group.
  #
  # @param tokens [Array<String>]
  # @return [String]
  def signature(tokens)
    tokens.map { |token| token.start_with?("[") ? token : "a " }.join
  end

  private

  # Without blank lines and without the spaces inside a line: how many
  # blank lines are between two blocks, and on which side of a closing
  # tag a space is, says nothing about what the parser read. The
  # indentation stays, it says how deep a list item is.
  def markdown
    yield
      .markdown
      .lines
      .map { |line| line[/\A */] + line.delete(" \t\n") }
      .reject(&:empty?)
      .join("\n")
  end
end
