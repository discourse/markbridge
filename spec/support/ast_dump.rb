# frozen_string_literal: true

# Prints an AST as indented lines, one node per line. +Node#inspect+
# prints instance variables and is hard to read once a tree has a few
# levels.
module AstDump
  AST = Markbridge::AST

  # @param node [Markbridge::AST::Node]
  # @param level [Integer] indentation level of +node+
  # @return [String]
  def self.dump(node, level: 0)
    lines = ["#{"  " * level}#{describe(node)}"]
    if node.is_a?(AST::Element)
      node.children.each { |child| lines << dump(child, level: level + 1) }
    end
    lines.join("\n")
  end

  # @param node [Markbridge::AST::Node]
  # @return [String] one line with the node's class and its own attributes
  def self.describe(node)
    name = node.class.name.split("::").last

    case node
    when AST::Text, AST::MarkdownText
      "#{name} #{node.text.inspect}"
    when AST::List
      "#{name} ordered=#{node.ordered?}"
    when AST::Code
      "#{name} block=#{node.block.inspect} language=#{node.language.inspect}"
    when AST::Url
      "#{name} href=#{node.href.inspect}"
    when AST::Email
      "#{name} address=#{node.address.inspect}"
    when AST::Image
      "#{name} src=#{node.src.inspect} alt=#{node.alt.inspect}"
    when AST::Heading
      "#{name} level=#{node.level}"
    when AST::Align
      "#{name} alignment=#{node.alignment.inspect}"
    else
      name
    end
  end
end
