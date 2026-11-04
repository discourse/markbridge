# frozen_string_literal: true

# Makes a failing AST smaller while it still fails, so that a failure
# report shows the few nodes that matter and not the forty the generator
# built. Three moves are tried in turn until none of them works any more:
# remove a node, replace an element with its children, shorten a text.
#
#   AstShrinker.shrink(document) { |candidate| still_fails?(candidate) }
#
# The document is changed in place. Every move is undone when the block
# says the candidate does not fail any more.
module AstShrinker
  AST = Markbridge::AST

  # @param document [Markbridge::AST::Element]
  # @yieldparam candidate [Markbridge::AST::Element] the document after a move
  # @yieldreturn [Boolean] whether the candidate still fails
  # @return [Markbridge::AST::Element] the same document, shrunk
  def self.shrink(document, &still_fails)
    loop do
      unless remove_node(document, &still_fails) || unwrap_element(document, &still_fails) ||
               shorten_text(document, &still_fails)
        break
      end
    end
    document
  end

  # Removes the first node whose removal keeps the failure. One move per
  # call: the list of elements is taken again afterwards, so a detached
  # element is never worked on.
  def self.remove_node(document)
    each_element(document) do |element|
      element.children.each_index do |index|
        children = element.children.dup
        element.replace_children(children.reject.with_index { |_, i| i == index })
        return true if yield(document)

        element.replace_children(children)
      end
    end
    false
  end

  def self.unwrap_element(document)
    each_element(document) do |element|
      element.children.each_with_index do |child, index|
        next unless child.is_a?(AST::Element) && !child.children.empty?

        children = element.children.dup
        element.replace_children(children[0...index] + child.children + children[(index + 1)..])
        return true if yield(document)

        element.replace_children(children)
      end
    end
    false
  end

  # Tries each half of a text, then the text without its first and
  # without its last character. A text of one character is left alone,
  # removing the node covers it.
  def self.shorten_text(document)
    each_element(document) do |element|
      element.children.each do |child|
        next unless child.is_a?(AST::Text) || child.is_a?(AST::MarkdownText)

        text = child.text
        next if text.length <= 1

        half = text.length / 2
        [text[0, half], text[half..], text[1..], text[0..-2]].uniq.each do |shorter|
          next if shorter.empty?

          replacement = child.class.new(shorter)
          element.replace_child(child, replacement)
          return true if yield(document)

          element.replace_child(replacement, child)
        end
      end
    end
    false
  end

  # The document and every element below it, parents first.
  def self.each_element(document, &block)
    yield document
    document.descendants(AST::Element).each(&block)
  end

  private_class_method :remove_node, :unwrap_element, :shorten_text, :each_element
end
