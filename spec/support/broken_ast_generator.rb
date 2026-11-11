# frozen_string_literal: true

require_relative "ast_generator"

# Builds trees the normalizer has to repair. AstGenerator stays inside
# what the normalizer accepts; this generator takes one of its trees
# and puts what does not belong there into an inline element: a block
# into bold, a list into a link, a link into a link.
#
#   BrokenAstGenerator.new(42).document
#
# Every choice comes from the seed, like in AstGenerator.
class BrokenAstGenerator
  AST = Markbridge::AST

  CONTAINERS = Markbridge::Normalizer::INLINE_CONTAINERS
  WORDS = %w[erin frank grace heidi].freeze
  MISPLACED = %i[quote list code heading rule table paragraph link].freeze

  # @param seed [Integer]
  def initialize(seed)
    @seed = seed
    @rng = Random.new(seed)
    @words = 0
  end

  # @return [Markbridge::AST::Document] a tree with one to three nodes
  #   in a place the default normalizer does not accept
  def document
    document = AstGenerator.new(@seed).document
    @rng.rand(1..3).times { misplace(document) }
    document
  end

  private

  def misplace(document)
    container = pick_container(document)
    index = @rng.rand(0..container.children.size)
    children = container.children.dup
    children.insert(index, build(MISPLACED.sample(random: @rng)))
    container.replace_children(children)
  end

  # An inline container of the tree, or a new one at the end of the
  # document when the tree has none.
  def pick_container(document)
    found = document.descendants(AST::Element).select { |node| CONTAINERS.include?(node.class) }
    return found.sample(random: @rng) unless found.empty?

    bold = AST::Bold.new << text
    document << (AST::Paragraph.new << text << bold << text)
    bold
  end

  def build(kind)
    case kind
    when :quote
      AST::Quote.new << (AST::Paragraph.new << text)
    when :list
      AST::List.new(ordered: @rng.rand(2).zero?) << (AST::ListItem.new << text) <<
        (AST::ListItem.new << text)
    when :code
      AST::Code.new(block: true) << AST::Text.new("#{word}\n#{word}")
    when :heading
      AST::Heading.new(level: @rng.rand(1..3)) << text
    when :rule
      AST::HorizontalRule.new
    when :table
      AST::Table.new << (AST::TableRow.new << (AST::TableCell.new << text))
    when :paragraph
      AST::Paragraph.new << text
    when :link
      AST::Url.new(href: "https://example.org/#{word}") << text
    end
  end

  def text
    AST::Text.new(word)
  end

  # No word twice, so a word that is made of two of them is seen.
  def word
    @words += 1
    "#{WORDS.sample(random: @rng)}#{@words}"
  end
end
