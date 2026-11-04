# frozen_string_literal: true

# Builds small documents that put two nodes next to each other on purpose.
# Whether Markdown means what the AST says depends on the neighbors: the
# flanking rules of emphasis, where an autolink ends, a `!` in front of a
# `[`, whether two lists merge. The random trees of AstGenerator meet
# such pairs by chance, this generator walks them all.
#
# Two families of cases:
#
# - Inline pairs: a left node and a right node, each with a character
#   class at the edge that faces the other, in one of five positions
#   (inside a paragraph, at the start of a line, in a list item, in a
#   link label, in a quote). Ids look like `paragraph/text(*)+bold(a)`.
# - Block pairs: two blocks (two lists, a quote, a code block, a heading)
#   with something or nothing between them, or a list followed by text,
#   in a document, a list item or a quote. Ids look like
#   `blocks/item/ul+space+ol`.
#
# Every case is an object that builds a fresh tree on each call of
# +document+, so a tree that got shrunk does not change the case.
module AdjacencyGenerator
  AST = Markbridge::AST

  # An element the tag library has no tag for. The renderer writes its
  # children, and the element is what the tags see as their neighbor.
  class Untagged < AST::Element
  end

  # One representative per character class, keyed by the name that shows
  # in a case id. Everything but the whitespace is its own name.
  EDGES = {
    "a" => "a",
    "1" => "1",
    "space" => " ",
    "*" => "*",
    "_" => "_",
    "~" => "~",
    "`" => "`",
    "!" => "!",
    "[" => "[",
    "]" => "]",
    "(" => "(",
    ")" => ")",
    "<" => "<",
    ">" => ">",
    "&" => "&",
    "\\" => "\\",
    "#" => "#",
    "|" => "|",
    "." => ".",
    "-" => "-",
    ":" => ":",
    "dot-space" => ". ",
    "nbsp" => " ",
    "“" => "“",
    "「" => "「",
    "€" => "€",
    "漢" => "漢",
    "😀" => "😀",
  }.freeze

  # Edges that mean something in Markdown. A MarkdownText carries Markdown
  # as it is, so with one of these at its edge nobody can say what the
  # text was meant to be; MarkdownText gets the other edges only.
  MARKDOWN_EDGES = %w[* _ ~ ` ! [ ] ( ) < > & \\ # | -].freeze
  PLAIN_EDGES = (EDGES.keys - MARKDOWN_EDGES).freeze

  HREF = "https://example.com/path"
  RELATIVE_HREF = "/relative/path"
  ADDRESS = "alice@example.com"
  IMAGE_SRC = "https://example.com/image.png"

  # A node kind with the character at the edge that faces its neighbor.
  # +edge+ is nil for the kinds whose content is fixed.
  Variant =
    Data.define(:kind, :edge) do
      def id
        edge ? "#{kind}(#{edge})" : kind
      end

      # @param side [Symbol] :left puts the edge at the end of the content,
      #   :right at its start
      # @return [Markbridge::AST::Node]
      def build(side)
        AdjacencyGenerator.build_variant(kind, content(side))
      end

      def content(side)
        return unless edge

        char = EDGES.fetch(edge)
        side == :left ? "x#{char}" : "#{char}y"
      end

      # A link inside a link label is what the normalizer unwraps.
      def link?
        %w[link email url relative].include?(kind)
      end
    end

  EDGED_KINDS = %w[text markdown bold italic strike code link email image].freeze
  FIXED_KINDS = %w[url relative break empty untagged].freeze

  VARIANTS =
    EDGED_KINDS
      .flat_map do |kind|
        edges = kind == "markdown" ? PLAIN_EDGES : EDGES.keys
        edges.map { |edge| Variant.new(kind:, edge:) }
      end
      .concat(FIXED_KINDS.map { |kind| Variant.new(kind:, edge: nil) })
      .freeze
  LABEL_VARIANTS = VARIANTS.reject(&:link?).freeze
  TEXT_VARIANTS = VARIANTS.select { |variant| variant.kind == "text" }.freeze
  VARIANTS_BY_ID = VARIANTS.to_h { |variant| [variant.id, variant] }.freeze

  def self.build_variant(kind, content)
    case kind
    when "text"
      AST::Text.new(content)
    when "markdown"
      AST::MarkdownText.new(content)
    when "bold"
      AST::Bold.new << AST::Text.new(content)
    when "italic"
      AST::Italic.new << AST::Text.new(content)
    when "strike"
      AST::Strikethrough.new << AST::Text.new(content)
    when "code"
      AST::Code.new << AST::Text.new(content)
    when "link"
      AST::Url.new(href: HREF) << AST::Text.new(content)
    when "email"
      AST::Email.new(address: ADDRESS) << AST::Text.new(content)
    when "image"
      AST::Image.new(src: IMAGE_SRC, alt: content)
    when "url"
      AST::Url.new(href: HREF) << AST::Text.new(HREF)
    when "relative"
      AST::Url.new(href: RELATIVE_HREF) << AST::Text.new(RELATIVE_HREF)
    when "break"
      AST::LineBreak.new
    when "empty"
      AST::Bold.new
    when "untagged"
      Untagged.new << AST::Text.new("x")
    else
      raise ArgumentError, "unknown variant kind #{kind.inspect}"
    end
  end

  # Where an inline pair sits. Each builds the document around the two
  # nodes. Text on the outer side of the pair ends in a space, so only
  # the inner edges face something other than whitespace.
  INLINE_POSITIONS = {
    "paragraph" => ->(left, right) do
      AST::Document.new([AST::Text.new("x "), left, right, AST::Text.new(" y")])
    end,
    "line" =>
      lambda do |left, right|
        AST::Document.new(
          [AST::Text.new("x"), AST::LineBreak.new, left, right, AST::Text.new(" y")],
        )
      end,
    "item" => ->(left, right) do
      AST::Document.new([AST::List.new << (AST::ListItem.new << left << right)])
    end,
    "label" => ->(left, right) { AST::Document.new([AST::Url.new(href: HREF) << left << right]) },
    "quote" => ->(left, right) { AST::Document.new([AST::Quote.new << left << right]) },
  }.freeze

  InlineCase =
    Data.define(:position, :left, :right) do
      def id
        "#{position}/#{left.id}+#{right.id}"
      end

      def family
        :inline
      end

      def document
        INLINE_POSITIONS.fetch(position).call(left.build(:left), right.build(:right))
      end
    end

  # The variants a position takes on either side.
  def self.variants_for(position)
    position == "label" ? LABEL_VARIANTS : VARIANTS
  end

  # [position, variants, offset of the position's first case]
  INLINE_GROUPS =
    INLINE_POSITIONS
      .keys
      .each_with_object([]) do |position, groups|
        offset = groups.empty? ? 0 : groups.last[2] + groups.last[1].size**2
        groups << [position, variants_for(position), offset].freeze
      end
      .freeze

  def self.inline_size
    group = INLINE_GROUPS.last
    group[2] + group[1].size**2
  end

  # @param index [Integer] 0 up to inline_size - 1
  # @return [InlineCase]
  def self.inline_at(index)
    position, variants, offset = INLINE_GROUPS.reverse_each.find { |group| group[2] <= index }
    local = index - offset
    InlineCase.new(
      position:,
      left: variants[local / variants.size],
      right: variants[local % variants.size],
    )
  end

  # @return [Enumerator<InlineCase>] every inline case, in id order
  def self.inline_cases
    Enumerator.new { |yielder| inline_size.times { |index| yielder << inline_at(index) } }
  end

  # A fixed subset of the inline cases. The same count and seed give the
  # same cases as long as the dimensions do not change.
  # @return [Array<InlineCase>]
  def self.inline_sample(count, seed:)
    indices = (0...inline_size).to_a.sample(count, random: Random.new(seed)).sort
    indices.map { |index| inline_at(index) }
  end

  BLOCKS = {
    "ul" => -> { AST::List.new << (AST::ListItem.new << AST::Text.new("x")) },
    "ol" => -> { AST::List.new(ordered: true) << (AST::ListItem.new << AST::Text.new("x")) },
    "quote" => -> { AST::Quote.new << AST::Text.new("x") },
    "code" => -> { AST::Code.new(block: true) << AST::Text.new("x = 1") },
    "heading" => -> { AST::Heading.new(level: 2) << AST::Text.new("x") },
  }.freeze
  LISTS = %w[ul ol].freeze

  # What stands between two blocks. Whitespace, a line break and an
  # element that renders to nothing must not keep two lists apart or
  # make one of them loose.
  BETWEEN = {
    "none" => nil,
    "space" => -> { AST::Text.new(" ") },
    "newline" => -> { AST::Text.new("\n") },
    "break" => -> { AST::LineBreak.new },
    "empty" => -> { AST::Bold.new },
  }.freeze

  # Every block position starts with a word, so the blocks follow text as
  # they do in a post.
  BLOCK_POSITIONS = {
    "document" => ->(nodes) { AST::Document.new([AST::Text.new("x"), *nodes]) },
    "item" =>
      lambda do |nodes|
        item = AST::ListItem.new << AST::Text.new("x")
        nodes.each { |node| item << node }
        AST::Document.new([AST::List.new << item])
      end,
    "quote" =>
      lambda do |nodes|
        quote = AST::Quote.new << AST::Text.new("x")
        nodes.each { |node| quote << node }
        AST::Document.new([quote])
      end,
  }.freeze

  BlockCase =
    Data.define(:position, :left, :between, :right) do
      def id
        "blocks/#{position}/#{left}+#{between}+#{right}"
      end

      def family
        :block
      end

      def document
        nodes = [BLOCKS.fetch(left).call]
        nodes << BETWEEN.fetch(between).call if BETWEEN.fetch(between)
        nodes << (BLOCKS[right] ? BLOCKS[right].call : VARIANTS_BY_ID.fetch(right).build(:right))
        BLOCK_POSITIONS.fetch(position).call(nodes)
      end
    end

  # Block pairs: every block next to every block, two lists with
  # something between them, and a list followed by text (with and
  # without a line break between), in every block position.
  # @return [Array<BlockCase>]
  def self.block_cases
    @block_cases ||=
      BLOCK_POSITIONS
        .keys
        .flat_map do |position|
          pairs = BLOCKS.keys.product(BLOCKS.keys).map { |left, right| [left, "none", right] }
          pairs.concat(LISTS.product(BETWEEN.keys - ["none"], LISTS))
          pairs.concat(LISTS.product(%w[none break], TEXT_VARIANTS.map(&:id)))
          pairs.map { |left, between, right| BlockCase.new(position:, left:, between:, right:) }
        end
        .freeze
  end

  # @param id [String]
  # @return [InlineCase, BlockCase, nil] the case with this id
  def self.find(id)
    return block_cases.find { |kase| kase.id == id } if id.start_with?("blocks/")

    position, pair = id.split("/", 2)
    return unless pair && INLINE_POSITIONS.key?(position)

    left, right = pair.split("+", 2).map { |variant_id| VARIANTS_BY_ID[variant_id] }
    unless left && right && variants_for(position).include?(left) &&
             variants_for(position).include?(right)
      return
    end

    InlineCase.new(position:, left:, right:)
  end
end
