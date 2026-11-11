# frozen_string_literal: true

require "cgi"

# Writes an AST as HTML, for the HTML round trip (HtmlRoundTripChecker):
# the trees of AstGenerator become input for the HTML parser.
#
#   AstHtmlWriter.lower(document)                      # only what HTML can say
#   AstHtmlWriter.new(AstHtmlWriter::STYLES[:divs]).write(document)
#
# A style is one way to write the same tree, like two authors or two
# exporters would: `<b>` or `<strong>`, a paragraph as `<p>` or as
# `<div>`, everything on one line or every block on its own.
class AstHtmlWriter
  AST = Markbridge::AST

  # +paragraph+ is the tag of a paragraph, +old+ picks `<b>`, `<i>` and
  # `<strike>`, +separator+ goes between block tags, +wrapper+ is a tag
  # around the whole document, +span+ puts every text into a `<span>`
  # and +tbody+ the rows of a table into a `<tbody>`.
  Style = Data.define(:paragraph, :old, :separator, :wrapper, :span, :tbody)

  STYLES = {
    plain:
      Style.new(paragraph: "p", old: false, separator: "", wrapper: nil, span: false, tbody: false),
    lines:
      Style.new(
        paragraph: "p",
        old: false,
        separator: "\n",
        wrapper: nil,
        span: false,
        tbody: true,
      ),
    divs:
      Style.new(
        paragraph: "div",
        old: false,
        separator: "",
        wrapper: "div",
        span: false,
        tbody: false,
      ),
    old:
      Style.new(
        paragraph: "p",
        old: true,
        separator: "\n  ",
        wrapper: nil,
        span: false,
        tbody: false,
      ),
    spans:
      Style.new(
        paragraph: "div",
        old: false,
        separator: "\n",
        wrapper: "section",
        span: true,
        tbody: false,
      ),
  }.freeze

  INLINE_TAGS = {
    AST::Bold => %w[strong b],
    AST::Italic => %w[em i],
    AST::Strikethrough => %w[s strike],
    AST::Superscript => %w[sup sup],
    AST::Subscript => %w[sub sub],
    AST::Insertion => %w[ins ins],
    AST::Deletion => %w[del del],
    AST::Highlight => %w[mark mark],
  }.freeze

  BLOCK_TAGS = { AST::ListItem => "li", AST::Quote => "blockquote", AST::TableRow => "tr" }.freeze

  # Elements with no HTML tag that the parser reads back as the same
  # node, or whose Markdown is BBCode that plain markdown-it shows as
  # text. Their children take their place.
  UNWRAPPED = [
    AST::Underline,
    AST::Spoiler,
    AST::Color,
    AST::Size,
    AST::Align,
    AST::Details,
    AST::Email,
  ].freeze

  # Leaves with no HTML form. A word takes their place.
  REPLACED = [AST::Mention, AST::Upload, AST::Poll, AST::Event, AST::MarkdownText].freeze

  # Reduces +document+ (in place) to the nodes HTML has a tag for.
  #
  # @param document [Markbridge::AST::Document]
  # @return [Markbridge::AST::Document] the same document
  def self.lower(document)
    lower_children(document)
    document
  end

  def self.lower_children(element)
    lowered =
      element.children.flat_map do |child|
        if REPLACED.include?(child.class)
          [AST::Text.new("thing")]
        elsif child.is_a?(AST::Element)
          lower_children(child)
          UNWRAPPED.include?(child.class) ? child.children : [child]
        else
          [child]
        end
      end
    # Through << and not replace_children, so texts that touch now are
    # one text, like in a tree a parser builds.
    element.replace_children([])
    lowered.each { |child| element << child }
  end

  private_class_method :lower_children

  # @param style [Style]
  def initialize(style)
    @style = style
  end

  # @param document [Markbridge::AST::Document] a lowered document
  # @return [String]
  def write(document)
    html = children(document)
    @style.wrapper ? "<#{@style.wrapper}>#{html}</#{@style.wrapper}>" : html
  end

  private

  def children(element)
    out = +""
    element.children.each_with_index do |child, index|
      # Whitespace next to a block tag shows nothing, a browser drops it.
      if index.positive? && (block?(child) || block?(element.children[index - 1]))
        out << @style.separator
      end
      out << node(child)
    end
    out
  end

  def node(node)
    case node
    when AST::Text
      text = CGI.escapeHTML(node.text)
      @style.span ? "<span>#{text}</span>" : text
    when AST::LineBreak
      "<br>"
    when AST::HorizontalRule
      "<hr>"
    when AST::Image
      %(<img src="#{CGI.escapeHTML(node.src.to_s)}" alt="#{CGI.escapeHTML(node.alt.to_s)}">)
    when AST::Code
      code(node)
    when AST::Url
      %(<a href="#{CGI.escapeHTML(node.href.to_s)}">#{children(node)}</a>)
    when AST::Paragraph
      tag(@style.paragraph, node)
    when AST::Heading
      tag("h#{node.level}", node)
    when AST::List
      tag(node.ordered? ? "ol" : "ul", node)
    when AST::Table
      rows = children(node)
      "<table>#{@style.tbody ? "<tbody>#{rows}</tbody>" : rows}</table>"
    when AST::TableCell
      tag(node.header? ? "th" : "td", node)
    else
      name = BLOCK_TAGS[node.class] || INLINE_TAGS.fetch(node.class).fetch(@style.old ? 1 : 0)
      tag(name, node)
    end
  end

  def tag(name, element)
    "<#{name}>#{children(element)}</#{name}>"
  end

  def code(node)
    text = CGI.escapeHTML(node.children.map(&:text).join)
    block_code?(node) ? "<pre><code>#{text}</code></pre>" : "<code>#{text}</code>"
  end

  def block_code?(node)
    node.block || node.children.any? { |child| child.text.include?("\n") }
  end

  def block?(node)
    case node
    when AST::Paragraph, AST::Heading, AST::List, AST::ListItem, AST::Quote, AST::Table,
         AST::TableRow, AST::TableCell, AST::HorizontalRule
      true
    when AST::Code
      block_code?(node)
    else
      false
    end
  end
end
