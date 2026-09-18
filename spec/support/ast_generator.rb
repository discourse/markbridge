# frozen_string_literal: true

# Builds random ASTs for the structure round-trip spec. Every choice comes
# from +Random.new(seed)+, so the same seed always builds the same tree and
# a failing example can be repeated from its seed alone.
#
#   AstGenerator.new(42).document
#
# The trees stay inside what the default normalizer already accepts, so the
# normalizer does not rewrite them and the expected structure can be read
# off the same tree that was rendered.
class AstGenerator
  AST = Markbridge::AST

  # Nesting limit, counted in block containers. The Document is level 1, so
  # 4 allows a list three levels deep — the shape of the indentation bug
  # that started this spec.
  MAX_DEPTH = 4

  # Node budget per document. Small trees keep a failing example readable.
  MAX_NODES = 40

  WORDS = %w[alice bob carol dave item note value entry].freeze

  # Tokens the escaper has to neutralize. They are placed in nested
  # positions on purpose: inside a list item or a quote they end up at the
  # start of a line, where CommonMark reads them as block markers.
  #
  # A bare "1." is left out. MarkdownEscaper escapes an ordered-list
  # marker only when a space or a tab follows it, so a line that is just
  # "1." cooks to an empty <ol><li></li></ol>. "- " and "# " at the end of
  # a line are escaped, only the ordered marker is not. The token with
  # text after it stays in, it covers the line-start case.
  TRICKY_TOKENS = [
    "*",
    "_",
    "#",
    "-",
    ">",
    "`",
    "[x]",
    "<b>",
    "|",
    "\\",
    "===",
    "two trailing spaces  ",
    "- looks like a bullet",
    "1. looks like an ordered item",
    "# looks like a heading",
  ].freeze

  # Lines for block code. Some carry leading spaces, some carry fence
  # characters, so the renderer has to widen the fence it picks.
  CODE_LINES = ["x = 1", "  indented", "end", "```", "~~~", "a | b", "# comment"].freeze

  # Lines that may follow the first one: a blank line and a line of
  # spaces have to survive the postprocessor unchanged.
  CODE_CONTINUATION_LINES = (CODE_LINES + ["", "  "]).freeze

  CODE_LANGUAGES = [nil, "ruby", "text"].freeze

  # Inline code stays on one line and carries no backtick, so the renderer
  # can wrap it in a single pair of backticks.
  INLINE_CODE_SNIPPETS = [
    "puts x",
    "a<b",
    "foo_bar",
    "a | b",
    "1 * 2",
    "a`b",
    "``",
    " x ",
    "`",
  ].freeze

  ALIGNMENTS = %w[left center right].freeze

  # No parentheses and no whitespace, so the link destination needs no
  # angle brackets and no balancing.
  HREFS = %w[
    https://example.com
    https://example.com/path
    https://example.com/a_b
    https://example.com/q?x=1&y=2
    /relative/path
  ].freeze

  INLINE_WRAPPERS = [AST::Bold, AST::Italic, AST::Strikethrough, AST::Url].freeze

  # Inline containers may nest this deep. Two levels are enough to put a
  # link inside emphasis without making the tree hard to read.
  MAX_INLINE_DEPTH = 2

  # Renders an AST as indented lines. +Node#inspect+ prints instance
  # variables and is hard to read once a tree has a few levels.
  #
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
  # @return [String] one line describing the node and its own attributes
  def self.describe(node)
    name = node.class.name.split("::").last

    case node
    when AST::Text
      "#{name} #{node.text.inspect}"
    when AST::List
      "#{name} ordered=#{node.ordered?}"
    when AST::Code
      "#{name} block=#{node.block.inspect} language=#{node.language.inspect}"
    when AST::Url
      "#{name} href=#{node.href.inspect}"
    when AST::Heading
      "#{name} level=#{node.level}"
    when AST::Align
      "#{name} alignment=#{node.alignment.inspect}"
    else
      name
    end
  end

  # @param seed [Integer]
  def initialize(seed)
    @random = Random.new(seed)
    @budget = MAX_NODES
  end

  # @return [Markbridge::AST::Document]
  def document
    @budget = MAX_NODES
    document = AST::Document.new
    fill_block_container(document, depth: 1, headings: true, in_list: false)
    document
  end

  private

  # Fills a block container (Document, ListItem, Quote, Align) with a mix
  # of inline runs and blocks. The first piece is always an inline run, so
  # every container holds at least one non-empty Text and the renderer
  # cannot drop it as empty.
  #
  # @param container [Markbridge::AST::Element]
  # @param depth [Integer] the container's own nesting level
  # @param headings [Boolean] whether a Heading may be placed here
  # @param in_list [Boolean] whether a List or ListItem is an ancestor
  # @return [void]
  def fill_block_container(container, depth:, headings:, in_list:)
    inline_run(container)
    (1 + @random.rand(3)).times do
      add_block(container, depth:, headings:, in_list:)
      # Below a list, a List is the last block its container may hold.
      # ListTag asks whether any ancestor is a List or a ListItem, and in
      # that case it drops the blank lines around the list. Whatever
      # follows then sits at the indentation of the last nested item and
      # CommonMark reads it as a continuation line of that item.
      break if in_list && container.children.last.is_a?(AST::List)
    end
  end

  # Appends one block, unless the budget is used up. Two Lists never end up
  # as neighbours: the renderer merges them into one loose list today,
  # which is a separate bug, so a text run goes between them.
  #
  # @return [void]
  def add_block(container, depth:, headings:, in_list:)
    return if exhausted?

    block = build_block(depth:, headings:, in_list:)
    return if block.nil?

    inline_run(container) if block.is_a?(AST::List) && container.children.last.is_a?(AST::List)
    container << block
  end

  # @return [Markbridge::AST::Node, nil]
  def build_block(depth:, headings:, in_list:)
    choices = %i[paragraph code_block rule]
    choices << :heading if headings
    choices.concat(%i[list quote align]) if depth < MAX_DEPTH

    case choices.sample(random: @random)
    when :paragraph
      paragraph
    when :code_block
      code_block
    when :rule
      spend { AST::HorizontalRule.new }
    when :heading
      heading
    when :list
      list(depth:)
    when :quote
      quote(depth:, in_list:)
    when :align
      align(depth:, in_list:)
    end
  end

  def paragraph
    paragraph = spend { AST::Paragraph.new }
    inline_run(paragraph)
    paragraph
  end

  # A heading is one line in Markdown, so its content carries no LineBreak.
  def heading
    heading = spend { AST::Heading.new(level: 1 + @random.rand(6)) }
    inline_run(heading, line_breaks: false)
    heading
  end

  def quote(depth:, in_list:)
    # No author: an attributed quote renders Discourse BBCode, which
    # commonmarker does not know.
    quote = spend { AST::Quote.new }
    fill_block_container(quote, depth: depth + 1, headings: true, in_list:)
    quote
  end

  def align(depth:, in_list:)
    align = spend { AST::Align.new(alignment: ALIGNMENTS.sample(random: @random)) }
    fill_block_container(align, depth: depth + 1, headings: true, in_list:)
    align
  end

  def list(depth:)
    list = spend { AST::List.new(ordered: @random.rand < 0.5) }
    list << list_item(depth: depth + 1)
    (@random.rand(3)).times do
      break if exhausted?
      list << list_item(depth: depth + 1)
    end
    list
  end

  # An item holds an inline run, sometimes a continuation line after a
  # LineBreak, and sometimes nested blocks. The continuation line is the
  # case the indentation bug hid in. A Heading stays out: a heading in an
  # item is unusual in a forum post and would only widen the spec.
  # A nested List ends the item, see {#fill_block_container}.
  def list_item(depth:)
    item = spend { AST::ListItem.new }
    inline_run(item)

    if @random.rand < 0.4 && !exhausted?
      item << AST::LineBreak.new
      inline_run(item)
    end

    (@random.rand(3)).times do
      add_block(item, depth:, headings: false, in_list: true)
      break if item.children.last.is_a?(AST::List)
    end
    item
  end

  # A run of inline nodes. It starts with a Text so the surrounding
  # container is never empty.
  #
  # @param container [Markbridge::AST::Element]
  # @param line_breaks [Boolean] whether a LineBreak may be part of the run
  # @return [void]
  def inline_run(container, line_breaks: true)
    container << text_node
    (@random.rand(3)).times do
      break if exhausted?
      container << inline_node(open: [], inline_depth: 0, line_breaks:)
    end
  end

  # @param open [Array<Class>] inline container classes already on the path
  # @return [Markbridge::AST::Node]
  def inline_node(open:, inline_depth:, line_breaks:)
    choices = %i[text inline_code]
    choices << :line_break if line_breaks
    choices << :wrapper if inline_depth < MAX_INLINE_DEPTH && wrappers_left(open).any?

    case choices.sample(random: @random)
    when :text
      text_node
    when :inline_code
      inline_code
    when :line_break
      spend { AST::LineBreak.new }
    else
      wrapper(open:, inline_depth:, line_breaks:)
    end
  end

  # An inline container never holds its own type again, and a link never
  # holds another link — the normalizer would rewrite both.
  def wrappers_left(open)
    INLINE_WRAPPERS - open
  end

  def wrapper(open:, inline_depth:, line_breaks:)
    klass = wrappers_left(open).sample(random: @random)
    node = spend { klass == AST::Url ? AST::Url.new(href: pick_href) : klass.new }

    # A Url with the href as its only text renders as a bare URL, which is
    # a different construct. A plain word first keeps it a real link
    # label. Everything after it may be a tricky token, also at the end:
    # emphasis that starts or ends with punctuation next to a word is
    # what the renderer's boundary comment is for.
    node << text_node(tricky: false)
    @random
      .rand(2)
      .times do
        break if exhausted?
        node << inline_node(open: open + [klass], inline_depth: inline_depth + 1, line_breaks:)
      end
    node
  end

  def text_node(tricky: true)
    spend { AST::Text.new(tricky && @random.rand < 0.35 ? tricky_token : phrase) }
  end

  def phrase
    Array.new(1 + @random.rand(3)) { WORDS.sample(random: @random) }.join(" ")
  end

  def tricky_token
    TRICKY_TOKENS.sample(random: @random)
  end

  def inline_code
    code = spend { AST::Code.new }
    code << AST::Text.new(INLINE_CODE_SNIPPETS.sample(random: @random))
    code
  end

  def code_block
    code = spend { AST::Code.new(language: CODE_LANGUAGES.sample(random: @random), block: true) }
    # The first line always has content, so the block is never empty.
    lines = [CODE_LINES.sample(random: @random)]
    @random.rand(3).times { lines << CODE_CONTINUATION_LINES.sample(random: @random) }
    code << AST::Text.new(lines.join("\n"))
    code
  end

  def pick_href
    HREFS.sample(random: @random)
  end

  def exhausted?
    @budget <= 0
  end

  def spend
    @budget -= 1
    yield
  end
end
