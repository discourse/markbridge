# frozen_string_literal: true

require_relative "round_trip_checker"

# Checks what the default normalizer makes of a tree it has to repair
# (see BrokenAstGenerator):
#
# - joined: no two words of the broken tree are one word in the repaired
#   tree. A block that moves out of bold stood between the words in
#   front of it and behind it, and they must not touch afterwards.
# - lost: the repaired tree has every character of the broken one
# - twice: a second run of the normalizer changes nothing
# - and the repaired tree round-trips, with the checks of
#   RoundTripChecker. Its first check is that the normalizer finds
#   nothing left to repair.
#
# A word may be in two parts afterwards, and the order may change: a
# block that moves out of an inline element is placed behind that
# element on purpose, so it can end up inside a word that went on
# behind the element.
class NormalizerRepairChecker
  AST = Markbridge::AST
  Failure = RoundTripChecker::Failure

  # Nodes whose content stands apart from the text around them.
  BLOCKS = [*Markbridge::Normalizer::BLOCK_NODES, AST::LineBreak, AST::Document].freeze

  # @param checker [RoundTripChecker] for the round trip of the repaired tree
  def initialize(checker = RoundTripChecker.new)
    @checker = checker
  end

  # @param document [Markbridge::AST::Document] a broken tree, left as it is
  # @return [Array<Failure>] empty when the repair is right
  def failures(document)
    repaired = repair(document)
    failures = []

    before = words(document)
    after = words(repaired)
    joined = after.reject { |word| before.any? { |whole| whole.include?(word) } }
    unless joined.empty?
      failures << Failure.new(
        check: :joined,
        message: "#{joined.inspect} are not words of the broken tree, which has #{before.inspect}",
      )
    end
    unless before.join.chars.sort == after.join.chars.sort
      failures << Failure.new(
        check: :lost,
        message: "the broken tree has the words #{before.inspect}, the repaired #{after.inspect}",
      )
    end

    again = Markbridge::Normalizer.shared_default.normalize(copy(repaired))
    unless again.empty?
      failures << Failure.new(
        check: :twice,
        message: "a second run still changes: #{again.inspect}",
      )
    end

    failures + @checker.failures(repaired)
  end

  # Shrinks +document+ in place as long as one of the checks that fail
  # now keeps failing.
  #
  # @param document [Markbridge::AST::Document]
  # @return [Markbridge::AST::Document] the same document
  def shrink(document)
    checks = failures(document).map(&:check)
    AstShrinker.shrink(document) do |candidate|
      failures(candidate).map(&:check).intersect?(checks)
    rescue StandardError
      false
    end
  end

  # @param document [Markbridge::AST::Document]
  # @param label [String]
  # @return [String]
  def explain(document, label:)
    before = document.descendants.size
    shrink(document)
    after = document.descendants.size

    label = "#{label}, shrunk from #{before} to #{after} nodes" if after < before
    report(document, label:)
  end

  # The broken tree, the repaired one, its Markdown and the failures.
  #
  # @param document [Markbridge::AST::Document]
  # @param label [String]
  # @return [String]
  def report(document, label:)
    repaired = repair(document)
    parts = [label, "", "Broken AST:", AstDump.dump(document), ""]
    parts << @checker.report(repaired, label: "Repaired:")
    failures(document)
      .reject { |failure| @checker.failures(repaired).include?(failure) }
      .each { |failure| parts << "" << "#{failure.check}: #{failure.message}" }
    parts.join("\n")
  end

  private

  def repair(document)
    repaired = copy(document)
    Markbridge::Normalizer.shared_default.normalize(repaired)
    repaired
  end

  def copy(document)
    Marshal.load(Marshal.dump(document))
  end

  # The words of the tree. Text that touches across the edge of an
  # inline element is one word, a block ends a word on both sides.
  def words(document)
    text(document, +"").split(/[[:space:]]+/).reject(&:empty?)
  end

  def text(node, out)
    case node
    when AST::Text, AST::MarkdownText
      out << node.text
    when AST::Element
      block = block?(node)
      out << " " if block
      node.children.each { |child| text(child, out) }
      out << " " if block
    else
      out << " " if block?(node)
    end
    out
  end

  def block?(node)
    BLOCKS.include?(node.class) || (node.is_a?(AST::Code) && node.block) ||
      (node.is_a?(AST::Spoiler) && node.block)
  end
end
