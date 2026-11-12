# frozen_string_literal: true

# Builds random BBCode for the comparison with s9e\TextFormatter
# (S9eDifferentialChecker): nested tags with text in them, and then a
# few of the mistakes people make. A closing tag is missing, two closing
# tags are in the wrong order, a closing tag has no opening tag.
#
#   BBCodeGenerator.new(42).tokens  # => ["[b]", "alice ", "[/b]", ...]
#
# The input is the tokens joined. They stay apart so that a failing
# input can be made smaller one token at a time. Every choice comes
# from the seed.
#
# What is left out on purpose, because Markbridge reads it differently
# and means to:
# - a `[*]`, a `[tr]` or a `[td]` with no list or table around it. For
#   s9e the tag is text, Markbridge reads an item or drops the tag. So
#   no opening tag of a list or a table part is taken away, and no
#   closing tag of one is put where it does not belong.
# - `[spoiler]`: a block for s9e in any place, for the BBCode parser a
#   part of the line.
# - `[sub]` and `[sup]`: s9e does not open them again behind a tag that
#   has ended them, Markbridge does, like for bold.
class BBCodeGenerator
  WORDS = %w[alice bob carol dave item note value entry].freeze

  # Tags with text in them, by the tag that opens them.
  INLINE = {
    "[b]" => "[/b]",
    "[i]" => "[/i]",
    "[u]" => "[/u]",
    "[s]" => "[/s]",
    "[color=red]" => "[/color]",
    "[size=20]" => "[/size]",
    "[url=https://example.com/a]" => "[/url]",
  }.freeze

  # Tags with blocks or text in them.
  BLOCKS = { "[quote]" => "[/quote]", "[center]" => "[/center]" }.freeze

  MAX_DEPTH = 4
  MAX_TOKENS = 30
  MISTAKES = %i[drop_close drop_open swap_closes stray_close].freeze
  CLOSE = %r{\A\[/}
  OPEN = /\A\[[a-z]/
  # Tags whose content is no text: taking one away leaves an item, a
  # row or a cell without the list or the table it belongs to.
  STRUCTURE = /\A\[(?:list|table|tr|td)\b/

  # The name of a tag: "url" for `[url=…]` and for `[/url]`.
  NAME = /[a-z]+/
  BLOCK_OPEN = /\A\[(?:quote|center|list|table)\b/
  NEEDS = { "[*]" => "[list", "[tr]" => "[table", "[td]" => "[tr" }.freeze

  # Why Markbridge and s9e read these tokens differently on purpose,
  # nil when they should read them the same way.
  #
  # - :orphan: a `[*]`, `[tr]` or `[td]` without the list, the table or
  #   the row it belongs to. s9e keeps the tag as text. Markbridge
  #   reads an item, and drops the tag of a row or a cell.
  # - :block_in_inline: a quote, an aligned block, a list or a table
  #   that opens inside bold, a link or another inline tag. Both sides
  #   end the inline tag in front of the block and give the text in the
  #   block a copy of it, and for a quote or a list the result is the
  #   same. The details differ: s9e takes nothing into a table and does
  #   not go on with the tag behind one, and it writes a link with
  #   nothing in it as its address.
  # - :link_in_link: a link that opens inside a link. s9e keeps the
  #   inner tag as text, Markbridge keeps its text only.
  # - :close_after_close: a closing tag that ends an inline tag with
  #   another one still open in it, and a closing tag right behind it.
  #   s9e opens the inner tag again in any case, Markbridge only when
  #   text or an opening tag follows, so a closing tag that closes
  #   nothing is text inside the inner tag for s9e and outside for
  #   Markbridge.
  #
  # @param tokens [Array<String>]
  # @return [Symbol, nil]
  def self.intended_difference(tokens)
    open = []
    tokens.each_with_index do |token, position|
      if token.match?(CLOSE)
        index = open.rindex { |tag| tag[NAME] == token[NAME] }
        next unless index

        inner = open[(index + 1)..]
        if !inner.empty? && inner.all? { |tag| INLINE.key?(tag) } &&
             tokens[position + 1]&.match?(CLOSE)
          return :close_after_close
        end

        # s9e opens the inline tags again that were open inside, so
        # they are still open for what follows.
        open.slice!(index..)
        open.concat(inner.select { |tag| INLINE.key?(tag) })
      elsif token.match?(OPEN) || token == "[*]"
        needed = NEEDS[token]
        return :orphan if needed && open.none? { |tag| tag.start_with?(needed) }
        return :block_in_inline if token.match?(BLOCK_OPEN) && open.any? { |tag| INLINE.key?(tag) }
        if token.start_with?("[url") && open.any? { |tag| tag.start_with?("[url") }
          return :link_in_link
        end

        open << token unless token == "[*]"
      end
    end
    nil
  end

  # @param seed [Integer]
  def initialize(seed)
    @rng = Random.new(seed)
  end

  # @return [Array<String>]
  def tokens
    @tokens = []
    content(depth: 0) while @tokens.size < 4
    @rng.rand(0..2).times { mistake }
    @tokens
  end

  private

  # +inline+ says that an inline tag is open: no block goes in there
  # (see .intended_difference), until a mistake takes its end away.
  def content(depth:, inline: false)
    @rng
      .rand(1..3)
      .times do
        break if @tokens.size >= MAX_TOKENS

        roll = @rng.rand(10)
        if roll < 4 || depth >= MAX_DEPTH
          text
        elsif roll < 7 || inline
          wrapped(INLINE, depth:, inline: true)
        elsif roll < 8
          wrapped(BLOCKS, depth:)
        elsif roll < 9
          list(depth:)
        else
          table(depth:)
        end
      end
  end

  def text
    @tokens << "#{Array.new(@rng.rand(1..2)) { WORDS.sample(random: @rng) }.join(" ")} "
  end

  def wrapped(tags, depth:, inline: false)
    open, close = tags.to_a.sample(random: @rng)
    @tokens << open
    content(depth: depth + 1, inline:)
    @tokens << close
  end

  def list(depth:)
    @tokens << (@rng.rand(3).zero? ? "[list=1]" : "[list]")
    @rng
      .rand(1..3)
      .times do
        @tokens << "[*]"
        content(depth: depth + 1)
      end
    @tokens << "[/list]"
  end

  def table(depth:)
    @tokens << "[table]"
    @rng
      .rand(1..2)
      .times do
        @tokens << "[tr]"
        @rng
          .rand(1..2)
          .times do
            @tokens << "[td]"
            content(depth: depth + 1)
            @tokens << "[/td]"
          end
        @tokens << "[/tr]"
      end
    @tokens << "[/table]"
  end

  def mistake
    closes = indexes(CLOSE)
    opens = indexes(OPEN)
    case MISTAKES.sample(random: @rng)
    when :drop_close
      @tokens.delete_at(closes.sample(random: @rng)) unless closes.empty?
    when :drop_open
      opens = opens.reject { |index| @tokens[index].match?(STRUCTURE) }
      @tokens.delete_at(opens.sample(random: @rng)) unless opens.empty?
    when :swap_closes
      index = closes.select { |i| closes.include?(i + 1) }.sample(random: @rng)
      @tokens[index], @tokens[index + 1] = @tokens[index + 1], @tokens[index] if index
    when :stray_close
      close = (INLINE.values + BLOCKS.values).sample(random: @rng)
      @tokens.insert(@rng.rand(0..@tokens.size), close)
    end
  end

  def indexes(pattern)
    @tokens.each_index.select { |index| @tokens[index].match?(pattern) }
  end
end
