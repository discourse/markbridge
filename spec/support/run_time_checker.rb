# frozen_string_literal: true

# Checks that the time of a conversion grows with the size of the input
# and not with its square. A parser that looks through the rest of the
# input for every token it reads is fast on a normal post and takes
# seconds on a post that somebody wrote to be slow, or that a broken
# export produced: 8,000 times `[[a ` and nothing that closes them.
#
# A case is a format and a short piece of markup. The piece is repeated
# n times and then 4n times, and both inputs are converted. With time
# that grows with the size the second run takes four times as long,
# with the square sixteen times. The limit is between the two.
#
#   kase = RunTimeChecker::Case.new(:mediawiki, "[[a ", "")
#   RunTimeChecker.growth(kase)  # => 4.1
#   RunTimeChecker.slow(kase)    # => nil
#
# The time is CPU time of this process and the best of three runs, so a
# busy machine does not change the result much. A case is measured on
# an input that takes a few milliseconds, small enough that a case
# with square growth is still done in a moment.
module RunTimeChecker
  FACTOR = 4
  LIMIT = 9.0
  # The smallest time worth comparing, and the size where the search
  # for it stops. An input of that size that converts faster has no
  # problem that anyone would notice.
  MEASURABLE = 0.003
  START_SIZE = 200
  MAX_SIZE = 25_600
  RUNS = 3

  CONVERTERS = {
    bbcode: ->(input) { Markbridge.bbcode_to_markdown(input, raise_on_error: false) },
    html: ->(input) { Markbridge.html_to_markdown(input, raise_on_error: false) },
    mediawiki: ->(input) { Markbridge.mediawiki_to_markdown(input, raise_on_error: false) },
    text_formatter: ->(input) do
      Markbridge.text_formatter_xml_to_markdown("<r>#{input}</r>", raise_on_error: false)
    end,
  }.freeze

  # Pieces every format gets: what opens or closes something, alone and
  # with text.
  TOKENS = {
    bbcode: [
      "[b]",
      "[/b]",
      "[b]x",
      "[b]x[/i]",
      "[i][b]x[/i]",
      "[quote]",
      "[/quote]",
      "[quote=a]x",
      "[list]",
      "[*]",
      "[list][*]x",
      "[*]x [quote]",
      "[/list]",
      "[code]",
      "[code]x[/code]",
      "[url]",
      "[url=",
      "[url=http://a.b]x",
      "[img]",
      "[table][tr][td]x",
      "[td]",
      "[/td]",
      "[spoiler]",
      "[color=red]x",
      "[size=",
      "[",
      "]",
      "[/",
      "[x",
      "[x]",
      "[b",
      "http://a.b/ ",
      "a@b.c ",
      "* ",
      "> ",
      "\\[",
    ],
    html: [
      "<b>",
      "</b>",
      "<b>x",
      "<i><b>x</i>",
      "<div>",
      "</div>",
      "<div>x</div>",
      "<p>",
      "<p>x",
      "<span>x",
      "<blockquote>",
      "<ul>",
      "<li>",
      "<ul><li>x",
      "<li>x<ul>",
      "<table>",
      "<tr>",
      "<td>",
      "<table><tr><td>x",
      "<pre>",
      "<pre>x</pre>",
      "<code>x",
      "<a href=\"x\">",
      "<a href=\"http://a.b\">x</a>",
      "<img src=\"x\">",
      "<br>",
      "<hr>",
      "<!--",
      "<!-- x -->",
      "<",
      ">",
      "</",
      "<x",
      "<x>",
      "&",
      "&amp;",
      "&#",
      " \n ",
      "<h1>x",
      "<details><summary>x",
    ],
    mediawiki: [
      "[[",
      "]]",
      "[[a ",
      "[[a|",
      "[[a]]",
      "[[File:a.png|",
      "[[File:a.png|x [[b]]",
      "[[Category:a]]",
      "[",
      "]",
      "[http://a.b ",
      "[http://a.b x]",
      "''",
      "'''",
      "'''''",
      "''x",
      "<nowiki>",
      "</nowiki>",
      "<nowiki>x",
      "<pre>",
      "</pre>",
      "<pre>x",
      "<b>",
      "<b>x",
      "</b>",
      "<ref>",
      "<br>",
      "<x>",
      "<",
      "{|",
      "|}",
      "|-",
      "| x",
      "|| x",
      "! x",
      "|+ x",
      "{{",
      "}}",
      "{{a|",
      "= x",
      "== x ==",
      "* x",
      "** x",
      "# x",
      "*# x",
      ": x",
      "; x",
      " x",
      "----",
      "&amp;",
    ],
    text_formatter: [
      "<B><s>[b]</s>x<e>[/b]</e></B>",
      "<QUOTE><s>[quote]</s>x<e>[/quote]</e></QUOTE>",
      "<LIST><LI>x</LI></LIST>",
      "<URL url=\"http://a.b\">x</URL>",
      "<p>x</p>",
      "<br/>",
      "x ",
      "<CODE>x</CODE>",
      "<IMG src=\"x\"/>",
      "<X>x</X>",
      "&amp;",
      "<EM><s>*</s>x<e>*</e></EM>",
      "<TABLE><TR><TD>x</TD></TR></TABLE>",
    ],
  }.freeze

  # The cases that are slow today, with the reason. They are left out
  # of the spec, and not expected to fail there: the growth of such a
  # case can be just at the limit, over it on one run and under it on
  # the next. bin/fuzz-parse says when one of them was fast.
  KNOWN = {
    %r{\Ahtml/\w+/"<!-- x -->"\z} =>
      "Nokogiri's HTML4 fragment parser takes time with the square of the number of " \
        "comments that are not inside an element; the time is spent before Markbridge " \
        "sees a node",
  }.freeze

  # How the pieces are put together: in one line, with a space between
  # them, and on lines of their own.
  SEPARATORS = { "" => "joined", " " => "spaced", "\n" => "lines" }.freeze

  Case =
    Data.define(:format, :token, :separator) do
      def id
        "#{format}/#{SEPARATORS.fetch(separator)}/#{token.inspect}"
      end

      def input(size)
        Array.new(size, token).join(separator)
      end
    end

  # @return [Array<Case>] every piece of every format with every separator
  def self.cases
    TOKENS.flat_map do |format, tokens|
      tokens.flat_map { |token| SEPARATORS.keys.map { |sep| Case.new(format, token, sep) } }
    end
  end

  # A part of the cases that is the same on every run: every +step+th
  # case, so each format and each separator is in it, without the cases
  # that are known to be slow.
  #
  # @return [Array<Case>]
  def self.sample(step)
    cases.each_slice(step).map(&:first).reject { |kase| known(kase) }
  end

  # @param kase [Case]
  # @return [String, nil] why the case is slow today
  def self.known(kase)
    KNOWN.find { |pattern, _| pattern.match?(kase.id) }&.last
  end

  # @param kase [Case]
  # @return [Float] how many times longer the conversion of the input
  #   takes when the input is FACTOR times as long. 0.0 when even the
  #   largest input converts too fast to measure.
  def self.growth(kase)
    converter = CONVERTERS.fetch(kase.format)
    size = START_SIZE
    time = measure(converter, kase.input(size))
    while time < MEASURABLE
      return 0.0 if size >= MAX_SIZE

      size *= 2
      time = measure(converter, kase.input(size))
    end

    measure(converter, kase.input(size * FACTOR)) / time
  end

  # @param kase [Case]
  # @return [Float, nil] the growth when it is over the limit, twice in
  #   a row: one measurement can be off when the machine is busy
  def self.slow(kase)
    first = growth(kase)
    return if first <= LIMIT

    second = growth(kase)
    [first, second].min if second > LIMIT
  end

  def self.measure(converter, input)
    Array
      .new(RUNS) do
        started = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
        converter.call(input)
        Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - started
      end
      .min
  end

  private_class_method :measure
end
