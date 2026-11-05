# frozen_string_literal: true

require "json"
require_relative "adjacency_generator"

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

  # One character per class, between or next to words. The classes are
  # the ones the adjacency round-trip builds its cases from.
  EDGE_CHARS = AdjacencyGenerator::EDGES.values.freeze

  # Tokens the escaper has to neutralize. They are placed in nested
  # positions on purpose: inside a list item or a quote they end up at the
  # start of a line, where CommonMark reads them as block markers.
  TRICKY_TOKENS = [
    "1.",
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
    "    four spaces",
    "\tone tab",
    "a\nb",
    "&amp;",
    "<!-- c -->",
    "\u200Bzero width",
  ].freeze

  # The Markdown of the CommonMark spec examples, one line at a time:
  # every construct the spec knows, as text the renderer must keep text.
  # Lines with a URL, a mail address or an autolink stay out: Discourse
  # links those in plain text on purpose, and the escaper keeps an
  # autolink as it is.
  LINKIFIED = %r{://|@|\b\w+\.(?:com|org|net|io|edu|gov|info|biz)\b|<[a-z][a-z0-9+.-]*:}i
  # The path is relative to this file, not SPEC_ROOT: bin/fuzz-render
  # loads the generator without spec_helper.
  COMMONMARK_LINES =
    JSON
      .parse(File.read(File.expand_path("../fixtures/commonmark_spec_0.31.2.json", __dir__)))
      .flat_map { |example| example["markdown"].lines(chomp: true) }
      .select { |line| line.match?(/[^[:space:]]/) && line.length <= 60 && !line.match?(LINKIFIED) }
      .uniq
      .freeze

  # Texts with nothing visible in them. They stand between nodes, never
  # first in a container.
  WHITESPACE_TEXTS = [" ", "  ", "\u00A0", "\n"].freeze

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

  # No whitespace, so no destination needs angle brackets. The three
  # before the relative path carry characters that need an escape in a
  # Markdown destination (a `]` cannot sit in a %w list).
  HREFS = [
    "https://example.com",
    "https://example.com/path",
    "https://example.com/a_b",
    "https://example.com/q?x=1&y=2",
    "https://example.com/a(b)c",
    "https://example.com/a]b",
    "https://example.com/a\\",
    "/relative/path",
  ].freeze

  INLINE_WRAPPERS = [
    AST::Bold,
    AST::Italic,
    AST::Strikethrough,
    AST::Url,
    AST::Underline,
    AST::Superscript,
    AST::Subscript,
    AST::Spoiler,
    AST::Color,
    AST::Size,
  ].freeze

  # Leaves and links that need no edge character of their own.
  INLINE_LEAVES = %i[image email mention upload].freeze

  COLORS = %w[red #ff0000].freeze
  SIZES = [10, 24].freeze

  # What makes a table fall back to HTML: rows of different widths, a
  # line break in a cell, or a block in a cell.
  HTML_TABLE_TRIGGERS = %i[uneven break block].freeze

  # Inline containers may nest this deep. Two levels are enough to put a
  # link inside emphasis without making the tree hard to read.
  MAX_INLINE_DEPTH = 2

  # @param seed [Integer]
  # @param seed [Integer]
  # @param attributed_quotes [Boolean] whether half of the quotes get an
  #   author or a post reference. Those are Discourse BBCode: Discourse
  #   finds the closing tag first and cooks the lines between as blocks,
  #   plain markdown-it reads `[/quote]` right after a table as a row of
  #   it. So only a run that cooks with the Discourse engine asks for
  #   them.
  def initialize(seed, attributed_quotes: false)
    @random = Random.new(seed)
    @attributed_quotes = attributed_quotes
  end

  # @return [Markbridge::AST::Document]
  def document
    @budget = MAX_NODES
    document = AST::Document.new
    fill_block_container(document, depth: 1, headings: true)
    document
  end

  private

  # Fills a block container (Document, ListItem, Quote, Align, Details)
  # with a mix
  # of inline runs and blocks. The first piece is always an inline run, so
  # every container holds at least one non-empty Text and the renderer
  # cannot drop it as empty.
  #
  # @param container [Markbridge::AST::Element]
  # @param depth [Integer] the container's own nesting level
  # @param headings [Boolean] whether a Heading may be placed here
  # @return [void]
  def fill_block_container(container, depth:, headings:)
    inline_run(container)
    (1 + @random.rand(3)).times { add_block(container, depth:, headings:) }
  end

  # Appends one block, unless the budget is used up.
  #
  # @return [void]
  def add_block(container, depth:, headings:)
    return if exhausted?

    block = build_block(depth:, headings:)
    container << block unless block.nil?
  end

  # @return [Markbridge::AST::Node, nil]
  def build_block(depth:, headings:)
    choices = %i[paragraph code_block rule table]
    choices << :heading if headings
    choices.concat(%i[list quote align details html_table]) if depth < MAX_DEPTH

    case choices.sample(random: @random)
    when :paragraph
      paragraph
    when :code_block
      code_block
    when :rule
      spend { AST::HorizontalRule.new }
    when :table
      table
    when :html_table
      html_table(depth:)
    when :heading
      heading
    when :list
      list(depth:)
    when :quote
      quote(depth:)
    when :align
      align(depth:)
    when :details
      details(depth:)
    end
  end

  # A table the renderer can write as a Markdown table: every row has
  # the same number of cells, the first row is the header, no cell has
  # a line break. The cells hold words only, a tricky token in a cell is
  # a case for the escaper, not for the table.
  def table
    table = spend { AST::Table.new }
    columns = 1 + @random.rand(3)
    (1 + @random.rand(3)).times do |index|
      row = spend { AST::TableRow.new }
      columns.times do
        cell = spend { AST::TableCell.new(header: index.zero?) }
        cell << AST::Text.new(phrase)
        row << cell
      end
      table << row
    end
    table
  end

  # A table the renderer writes as HTML, with everything in it in
  # html_mode: a line break, a block or another table in a cell, or rows
  # of different widths. One trigger is placed on purpose in the last
  # cell, the other cells get an inline run and sometimes a block. A
  # body cell is a header cell now and then: HTML keeps that, a
  # Markdown table cannot. The cells are block containers, so the table
  # counts as a nesting level.
  def html_table(depth:)
    table = spend { AST::Table.new }
    columns = 1 + @random.rand(2)
    rows = 1 + @random.rand(3)
    trigger = HTML_TABLE_TRIGGERS.sample(random: @random)
    trigger = :break if trigger == :uneven && rows == 1

    rows.times do |index|
      row = spend { AST::TableRow.new }
      count = columns
      count += 1 if trigger == :uneven && index == rows - 1
      count.times do |column|
        header = index.zero? || @random.rand < 0.2
        cell = spend { AST::TableCell.new(header:) }
        inline_run(cell)
        add_block(cell, depth: depth + 1, headings: false) if @random.rand < 0.3
        row << cell
      end
      table << row
    end

    last = table.children.last.children.last
    case trigger
    when :break
      last << AST::LineBreak.new
      inline_run(last)
    when :block
      last << build_block(depth: depth + 1, headings: false)
    end
    table
  end

  # A title half of the time, made of plain words: the renderer writes it
  # into the tag as it is.
  def details(depth:)
    title = "#{word} #{word}" if @random.rand(2).zero?
    details = spend { AST::Details.new(title:) }
    fill_block_container(details, depth: depth + 1, headings: false)
    details
  end

  def word
    WORDS.sample(random: @random)
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

  # With attributed quotes, half of them get a full post reference or a
  # name only (see #initialize).
  def quote(depth:)
    quote = spend { build_quote }
    fill_block_container(quote, depth: depth + 1, headings: true)
    quote
  end

  def build_quote
    return AST::Quote.new unless @attributed_quotes

    case @random.rand(4)
    when 0
      AST::Quote.new(
        username: word,
        post_number: 1 + @random.rand(9),
        topic_id: 1 + @random.rand(99),
      )
    when 1
      AST::Quote.new(author: word)
    else
      AST::Quote.new
    end
  end

  def align(depth:)
    align = spend { AST::Align.new(alignment: ALIGNMENTS.sample(random: @random)) }
    fill_block_container(align, depth: depth + 1, headings: true)
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
  def list_item(depth:)
    item = spend { AST::ListItem.new }
    inline_run(item)

    if @random.rand < 0.4 && !exhausted?
      item << AST::LineBreak.new
      inline_run(item)
    end

    @random.rand(3).times { add_block(item, depth:, headings: false) }
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
    choices = %i[text text inline_code whitespace leaf]
    choices << :line_break if line_breaks
    choices << :wrapper << :wrapper if inline_depth < MAX_INLINE_DEPTH && wrappers_left(open).any?

    case choices.sample(random: @random)
    when :text
      text_node
    when :inline_code
      inline_code
    when :whitespace
      spend { AST::Text.new(WHITESPACE_TEXTS.sample(random: @random)) }
    when :leaf
      inline_leaf(open:)
    when :line_break
      spend { AST::LineBreak.new }
    else
      wrapper(open:, inline_depth:, line_breaks:)
    end
  end

  # An image, a mail link, a mention or an upload. A link never holds
  # another link, so the mail link stays out of one.
  def inline_leaf(open:)
    choices = INLINE_LEAVES
    choices -= [:email] if open.include?(AST::Url)

    case choices.sample(random: @random)
    when :image
      spend { AST::Image.new(src: pick_href, alt: (@random.rand < 0.7 ? label_text : nil)) }
    when :email
      email = spend { AST::Email.new(address: "alice@example.com") }
      email << AST::Text.new(label_text)
      email
    when :mention
      spend { AST::Mention.new(name: WORDS.sample(random: @random)) }
    else
      spend { upload }
    end
  end

  # An image upload, half of them with dimensions, or a file attachment,
  # half of them with a size. The `|` in front of the dimensions and of
  # the attachment marker is what ends a table cell when it is not
  # escaped.
  def upload
    if @random.rand < 0.3
      size = @random.rand < 0.5 ? "1.2 KB" : nil
      AST::Upload.new(sha1: "abc123", filename: "#{label_text}.pdf", type: :attachment, size:)
    else
      dimensions = @random.rand < 0.5 ? "64x64" : nil
      AST::Upload.new(
        sha1: "abc123",
        filename: "image.png",
        type: :image,
        alt: label_text,
        dimensions:,
      )
    end
  end

  # Text for an alt text or a label: a phrase, sometimes with a
  # character class in it.
  def label_text
    @random.rand < 0.5 ? spliced_phrase : phrase
  end

  # An inline container never holds its own type again, and a link never
  # holds another link — the normalizer would rewrite both.
  def wrappers_left(open)
    INLINE_WRAPPERS - open
  end

  def wrapper(open:, inline_depth:, line_breaks:)
    klass = wrappers_left(open).sample(random: @random)
    node = spend { build_wrapper(klass) }

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

  def build_wrapper(klass)
    if klass == AST::Url
      AST::Url.new(href: pick_href)
    elsif klass == AST::Color
      AST::Color.new(color: COLORS.sample(random: @random))
    elsif klass == AST::Size
      AST::Size.new(size: SIZES.sample(random: @random))
    else
      klass.new
    end
  end

  # A phrase, a phrase with a character class spliced in, a tricky
  # token, or a line from the CommonMark spec.
  def text_node(tricky: true)
    roll = @random.rand
    text =
      if tricky && roll < 0.2
        TRICKY_TOKENS.sample(random: @random)
      elsif tricky && roll < 0.4
        COMMONMARK_LINES.sample(random: @random)
      elsif roll < 0.65
        spliced_phrase
      else
        phrase
      end
    spend { AST::Text.new(text) }
  end

  def phrase
    Array.new(1 + @random.rand(3)) { WORDS.sample(random: @random) }.join(" ")
  end

  # A character class at the start, at the end or between the words.
  def spliced_phrase
    char = EDGE_CHARS.sample(random: @random)
    case @random.rand(3)
    when 0
      "#{char}#{phrase}"
    when 1
      "#{phrase}#{char}"
    else
      "#{phrase}#{char}#{phrase}"
    end
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
