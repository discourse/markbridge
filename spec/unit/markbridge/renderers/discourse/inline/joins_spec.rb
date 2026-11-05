# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Inline::Joins do
  # Appends the parts one after the other and returns the buffer.
  def joined(*parts)
    parts.each_with_object(+"") { |part, buffer| described_class.append(buffer, part) }
  end

  describe ".append" do
    it "writes the first piece without a join" do
      expect(joined("*a*")).to eq("*a*")
    end

    it "returns the buffer" do
      buffer = +"a"

      expect(described_class.append(buffer, "b")).to be(buffer)
    end

    it "puts a boundary between two runs of the same delimiter" do
      expect(joined("**x**", "**y**")).to eq("**x**<!---->**y**")
    end

    it "puts a boundary between two code spans so the backtick runs do not merge" do
      expect(joined("`a`", "`b`")).to eq("`a`<!---->`b`")
    end

    it "puts no boundary between different delimiters" do
      expect(joined("**a**", "~~b~~")).to eq("**a**~~b~~")
    end

    it "puts no boundary between equal characters that are no delimiters" do
      expect(joined("a", "a")).to eq("aa")
    end

    it "puts a boundary between a word and emphasis that starts with punctuation" do
      expect(joined("item", "*\\#*")).to eq("item<!---->*\\#*")
    end

    it "puts a boundary between emphasis that ends with punctuation and a word" do
      expect(joined("**\\*bold\\***", "tail")).to eq("**\\*bold\\***<!---->tail")
    end

    it "treats a non-ASCII letter in front of the emphasis as a word character" do
      expect(joined("ä", "*\\#*")).to eq("ä<!---->*\\#*")
    end

    it "leaves emphasis that starts with a word character alone" do
      expect(joined("item", "*x*")).to eq("item*x*")
    end

    it "leaves emphasis alone when whitespace stands in front of it" do
      expect(joined("item ", "*\\#*")).to eq("item *\\#*")
    end

    it "leaves emphasis alone when punctuation stands in front of it" do
      expect(joined("(", "*\\#*")).to eq("(*\\#*")
    end

    it "leaves emphasis that ends with a word character alone in front of a word" do
      expect(joined("*x*", "tail")).to eq("*x*tail")
    end

    it "leaves emphasis that ends with punctuation alone in front of whitespace" do
      expect(joined("**\\*bold\\***", " tail")).to eq("**\\*bold\\*** tail")
    end

    it "puts a boundary between emphasis that ends with punctuation and strikethrough" do
      expect(joined("**a\\***", "~~b~~")).to eq("**a\\***<!---->~~b~~")
    end

    it "puts a boundary between strikethrough and emphasis that starts with punctuation" do
      expect(joined("~~a~~", "*\\#*")).to eq("~~a~~<!---->*\\#*")
    end

    it "leaves emphasis that ends with a word character alone in front of strikethrough" do
      expect(joined("**a**", "~~b~~")).to eq("**a**~~b~~")
    end

    it "puts a boundary between a word and an underscore run whatever follows the run" do
      expect(joined("a", "_x_")).to eq("a<!---->_x_")
    end

    it "puts a boundary between an underscore run and a word whatever precedes the run" do
      expect(joined("_x_", "a")).to eq("_x_<!---->a")
    end

    it "puts no boundary when the piece is nothing but a delimiter run" do
      expect(joined("a", "**")).to eq("a**")
    end

    it "puts no boundary when the run reaches the start of the buffer" do
      expect(joined("**", "a")).to eq("**a")
    end

    it "looks past the whole run for the character after it" do
      expect(joined("a", "***\\#***")).to eq("a<!---->***\\#***")
    end

    it "looks past the whole run for the character before it" do
      expect(joined("***\\#***", "a")).to eq("***\\#***<!---->a")
    end

    it "does not take the last character of the piece for the character after the run" do
      expect(joined("a", "*x#*")).to eq("a*x#*")
      expect(joined("a", "*x~")).to eq("a*x~")
      expect(joined("a", "**x~")).to eq("a**x~")
    end

    it "looks past a run of two in front of the join" do
      expect(joined("**x**", "a")).to eq("**x**a")
      expect(joined("**x.**", "a")).to eq("**x.**<!---->a")
    end

    # Unicode punctuation and symbols count as punctuation next to the
    # run, letters do not. One per UTF-8 length.
    {
      "“" => true,
      "€" => true,
      "„" => true,
      "😀" => true,
      "é" => false,
      "漢" => false,
    }.each do |char, punctuation|
      it "treats #{char.inspect} after the run as #{punctuation ? "punctuation" : "no punctuation"}" do
        expect(joined("a", "*#{char}x*")).to eq(punctuation ? "a<!---->*#{char}x*" : "a*#{char}x*")
      end

      it "treats #{char.inspect} in front of the run as #{punctuation ? "punctuation" : "no punctuation"}" do
        expect(joined("*x#{char}*", "a")).to eq(punctuation ? "*x#{char}*<!---->a" : "*x#{char}*a")
      end
    end

    # Every ASCII byte after the run and in front of it, at both ends of
    # each range the punctuation check knows, with the byte next to each
    # end.
    {
      "!" => true,
      "/" => true,
      "0" => false,
      "9" => false,
      ":" => true,
      "@" => true,
      "A" => false,
      "Z" => false,
      "[" => true,
      "`" => true,
      "a" => false,
      "z" => false,
      "{" => true,
      "~" => true,
      " " => false,
      "\t" => false,
    }.each do |char, punctuation|
      it "treats #{char.inspect} after the run as #{punctuation ? "punctuation" : "no punctuation"}" do
        expect(joined("a", "*#{char}x*")).to eq(punctuation ? "a<!---->*#{char}x*" : "a*#{char}x*")
      end

      it "treats #{char.inspect} in front of the run as #{punctuation ? "punctuation" : "no punctuation"}" do
        expect(joined("*x#{char}*", "a")).to eq(punctuation ? "*x#{char}*<!---->a" : "*x#{char}*a")
      end
    end

    it "reads one character after the run, also when more multi-byte characters follow" do
      expect(joined("a", "*“漢x*")).to eq("a<!---->*“漢x*")
      expect(joined("a", "*é漢x*")).to eq("a*é漢x*")
      expect(joined("a", "*😀😀*")).to eq("a<!---->*😀😀*")
    end

    it "finds the character in front of the run inside a multi-byte character" do
      expect(joined("*x“*", "a")).to eq("*x“*<!---->a")
      expect(joined("*xé*", "a")).to eq("*xé*a")
      expect(joined("*x😀**", "a")).to eq("*x😀**<!---->a")
    end

    it "puts the boundary between anything but whitespace and a piece that starts with @" do
      # The two would read as an email address with the text after them;
      # linkify takes punctuation into the local part too.
      expect(joined("a", "@b")).to eq("a<!---->@b")
      expect(joined("é", "@b")).to eq("é<!---->@b")
      expect(joined("1", "@b")).to eq("1<!---->@b")
      expect(joined("#", "@b")).to eq("#<!---->@b")
      expect(joined(".", "@b")).to eq(".<!---->@b")
      expect(joined("a ", "@b")).to eq("a @b")
      expect(joined("a\n", "@b")).to eq("a\n@b")
      expect(joined("a", "x@b")).to eq("ax@b")
    end

    it "escapes a ! at the end of the buffer when the next piece starts with [" do
      expect(joined("Hi!", "[x](/a)")).to eq("Hi\\![x](/a)")
    end

    it "leaves a ! that is already escaped alone" do
      expect(joined("Hi\\!", "[x](/a)")).to eq("Hi\\![x](/a)")
    end

    it "escapes a ! that follows an escaped backslash" do
      expect(joined("a\\\\!", "[x](/a)")).to eq("a\\\\\\![x](/a)")
    end

    it "leaves a ! alone after an odd run of backslashes" do
      expect(joined("a\\\\\\!", "[x](/a)")).to eq("a\\\\\\![x](/a)")
    end

    it "counts a backslash run that reaches the start of the buffer" do
      expect(joined("\\\\!", "[x](/a)")).to eq("\\\\\\![x](/a)")
      expect(joined("\\!", "[x](/a)")).to eq("\\![x](/a)")
    end

    it "escapes a ! after multibyte text by its byte offset" do
      expect(joined("ä!", "[x](/a)")).to eq("ä\\![x](/a)")
    end

    it "leaves a ! alone when the next piece does not start with [" do
      expect(joined("Hi!", "x")).to eq("Hi!x")
    end

    # The escaper would escape these inside one text, see
    # MarkdownEscaper; across two pieces the join has to.
    it "escapes a < at the end of the buffer when the next piece would start raw HTML" do
      expect(joined("x<", "!y")).to eq("x\\<!y")
      expect(joined("x<", "?y")).to eq("x\\<?y")
      expect(joined("x<", "/y")).to eq("x\\</y")
      expect(joined("x<", "div")).to eq("x\\<div")
      expect(joined("x<", "Z")).to eq("x\\<Z")
    end

    it "leaves a < alone in front of a digit, a space or a non-ASCII character" do
      expect(joined("x<", "5")).to eq("x<5")
      expect(joined("x<", " y")).to eq("x< y")
      expect(joined("x<", "äy")).to eq("x<äy")
    end

    it "leaves a < that is already escaped alone" do
      expect(joined("x\\<", "!y")).to eq("x\\<!y")
    end

    it "escapes the second of two dashes that meet, a dash to the typographer" do
      expect(joined("x-", "-y")).to eq("x-\\-y")
      expect(joined("x-", "-")).to eq("x-\\-")
    end

    it "leaves a dash alone next to anything else" do
      expect(joined("x-", "y")).to eq("x-y")
      expect(joined("x", "-y")).to eq("x-y")
      expect(joined("x-", "\\-y")).to eq("x-\\-y")
    end
  end

  describe ".append_like" do
    def append_like(buffer, piece, like, before = nil)
      described_class.append_like(+buffer, piece, like, before)
    end

    it "escapes a < in front of a placeholder that stands for raw HTML" do
      expect(append_like("x<", "[p|1]", "!y")).to eq("x\\<[p|1]")
    end

    it "keeps a dash apart from a placeholder that stands for one with a comment, no backslash can go there" do
      expect(append_like("x-", "[d|1]", "-y")).to eq("x-<!---->[d|1]")
    end

    it "escapes a dash after a placeholder with a backslash, the piece is real" do
      expect(append_like("[d|1]", "-y", nil, "x-")).to eq("[d|1]\\-y")
    end

    it "joins the piece as if like stood in its place" do
      expect(append_like("**a.**", "[l|1]", "https://e.com")).to eq("**a.**<!---->[l|1]")
      expect(append_like("**a.**", "[l|1]", "(x)")).to eq("**a.**[l|1]")
      expect(append_like("v", "[m|1]", "@alice")).to eq("v<!---->[m|1]")
      expect(append_like("x", "[l|1]", "**.a**")).to eq("x<!---->[l|1]")
    end

    it "escapes a ! in front of it when like starts with [" do
      expect(append_like("Look!", "u1", "[a](u)")).to eq("Look\\!u1")
      expect(append_like("Look!", "[l|1]", "https://e.com")).to eq("Look![l|1]")
    end

    it "joins with before in place of the end of the buffer" do
      expect(append_like("[l|1]", "**.a**", nil, "https://e.com/t")).to eq("[l|1]<!---->**.a**")
      expect(append_like("[l|1]", "**.a**", nil, "https://e.com/")).to eq("[l|1]**.a**")
      expect(append_like("[l|1]", "a", nil, "x **")).to eq("[l|1]a")
      expect(append_like("[l|1]", "a", nil, "x.**")).to eq("[l|1]<!---->a")
      expect(append_like("[l|1]", "[m|2]", "@bob", "https://e.com/")).to eq("[l|1]<!---->[m|2]")
    end

    it "keeps a ! at the end of before from making an image with a comment, a backslash can't go there" do
      expect(append_like("[l|1]", "[a](u)", nil, "wow!")).to eq("[l|1]<!---->[a](u)")
    end

    it "writes the first piece without a join" do
      expect(append_like("", "[l|1]", "@alice")).to eq("[l|1]")
    end

    it "returns the buffer" do
      buffer = +"a"

      expect(described_class.append_like(buffer, "b", "c")).to be(buffer)
    end
  end

  describe ".escaped_end?" do
    it "is true for an odd run of backslashes in front of the last character" do
      expect(described_class.escaped_end?("\\!")).to be(true)
      expect(described_class.escaped_end?("a\\\\\\!")).to be(true)
    end

    it "is false for an even run, or none" do
      expect(described_class.escaped_end?("!")).to be(false)
      expect(described_class.escaped_end?("a!")).to be(false)
      expect(described_class.escaped_end?("\\\\!")).to be(false)
      expect(described_class.escaped_end?("a\\\\!")).to be(false)
    end
  end

  # The byte classes and the actions are tables packed once, while the
  # class body runs. Mutation testing cannot reach the rules behind
  # them, a mutant redefines a method and by then the tables are built,
  # so these examples walk every entry and compare it with the rules
  # written out longhand.
  describe "the tables" do
    let(:byte_classes) { described_class.const_get(:BYTE_CLASSES) }
    let(:join_actions) { described_class.const_get(:JOIN_ACTIONS) }

    let(:class_names) do
      {
        described_class.const_get(:OTHER) => :other,
        described_class.const_get(:WORD) => :word,
        described_class.const_get(:PUNCTUATION) => :punctuation,
        described_class.const_get(:BANG) => :bang,
        described_class.const_get(:BRACKET) => :bracket,
        described_class.const_get(:BACKTICK) => :backtick,
        described_class.const_get(:STAR) => :star,
        described_class.const_get(:UNDERSCORE) => :underscore,
        described_class.const_get(:TILDE) => :tilde,
        described_class.const_get(:AT) => :at,
        described_class.const_get(:LT) => :lt,
        described_class.const_get(:DASH) => :dash,
      }
    end

    let(:action_names) do
      {
        described_class.const_get(:NOTHING) => :nothing,
        described_class.const_get(:BOUNDARY) => :boundary,
        described_class.const_get(:CHECK_AFTER) => :check_after,
        described_class.const_get(:CHECK_BEFORE) => :check_before,
        described_class.const_get(:ESCAPE_BEFORE) => :escape_before,
        described_class.const_get(:ESCAPE_AFTER) => :escape_after,
      }
    end

    # One byte per class. The action table has a row per class of the
    # byte in front of the join, not a row per byte, so one byte stands
    # for its whole class there.
    let(:representatives) do
      {
        other: " ",
        word: "a",
        punctuation: "%",
        bang: "!",
        bracket: "[",
        backtick: "`",
        star: "*",
        underscore: "_",
        tilde: "~",
        at: "@",
        lt: "<",
        dash: "-",
      }
    end

    # What a byte is to the join rules, written out longhand: the six
    # bytes the rules name, then CommonMark's word characters (ASCII
    # letters and digits, and every non-ASCII byte) and its ASCII
    # punctuation. Spaces and control bytes are neither.
    def expected_class(byte)
      case byte
      when "!".ord
        :bang
      when "[".ord
        :bracket
      when "`".ord
        :backtick
      when "*".ord
        :star
      when "_".ord
        :underscore
      when "~".ord
        :tilde
      when "@".ord
        :at
      when "<".ord
        :lt
      when "-".ord
        :dash
      when 48..57, 65..90, 97..122, 128..255
        :word
      when 33..47, 58..64, 91..96, 123..126
        :punctuation
      else
        :other
      end
    end

    # A word character keeps a delimiter run next to it from opening or
    # closing, and so does a tilde.
    def blocking?(byte)
      expected_class(byte) == :word || byte == "~".ord
    end

    # The join rules, written out longhand over the byte in front of the
    # join and the byte after it, in the order they are applied.
    def expected_action(before, after)
      merging = "*_~`".bytes
      flanking = "*_~".bytes

      html_start = "!/?".bytes + ("a".."z").map(&:ord) + ("A".."Z").map(&:ord)

      if before == after && merging.include?(before)
        :boundary
      elsif before == "!".ord && after == "[".ord
        :escape_before
      elsif before == "<".ord && html_start.include?(after)
        :escape_before
      elsif before == "-".ord && after == "-".ord
        :escape_after
      elsif flanking.include?(after) && blocking?(before)
        after == "_".ord ? :boundary : :check_after
      elsif flanking.include?(before) && blocking?(after)
        before == "_".ord ? :boundary : :check_before
      elsif after == "@".ord && expected_class(before) != :other
        :boundary
      else
        :nothing
      end
    end

    it "gives every class a number of its own" do
      expect(class_names.size).to eq(described_class.const_get(:CLASS_COUNT))
    end

    it "gives every action a number of its own" do
      expect(action_names.size).to eq(6)
    end

    it "holds a class for every byte" do
      expect(byte_classes.bytesize).to eq(256)
    end

    it "holds a row of 256 actions per class" do
      expect(join_actions.bytesize).to eq(class_names.size * 256)
    end

    it "classifies every byte the way the rules define it" do
      actual = (0..255).to_h { |byte| [byte, class_names.fetch(byte_classes.getbyte(byte))] }
      expected = (0..255).to_h { |byte| [byte, expected_class(byte)] }

      expect(actual).to eq(expected)
    end

    it "numbers every punctuation class at or above PUNCTUATION" do
      names = %i[punctuation bang bracket backtick star underscore tilde at lt dash]
      threshold = described_class.const_get(:PUNCTUATION)

      actual = (0..255).to_h { |byte| [byte, byte_classes.getbyte(byte) >= threshold] }
      expected = (0..255).to_h { |byte| [byte, names.include?(expected_class(byte))] }

      expect(actual).to eq(expected)
    end

    it "picks one byte per class to stand for it" do
      actual =
        representatives.transform_values do |char|
          class_names.fetch(byte_classes.getbyte(char.ord))
        end
      expected = representatives.keys.to_h { |name| [name, name] }

      expect(actual).to eq(expected)
    end

    it "picks the action the rules written out longhand pick" do
      actual = {}
      expected = {}

      representatives.each do |name, char|
        before = char.ord
        row = byte_classes.getbyte(before) << 8

        (0..255).each do |after|
          actual[[name, after]] = action_names.fetch(join_actions.getbyte(row + after))
          expected[[name, after]] = expected_action(before, after)
        end
      end

      expect(actual).to eq(expected)
    end
  end

  describe ".space_at?" do
    it "knows ASCII whitespace by its byte" do
      expect(described_class.space_at?("a b", 1)).to be(true)
      expect(described_class.space_at?("a\tb", 1)).to be(true)
      expect(described_class.space_at?("a\nb", 1)).to be(true)
      expect(described_class.space_at?("a\rb", 1)).to be(true)
      expect(described_class.space_at?("a\fb", 1)).to be(true)
      expect(described_class.space_at?("a\vb", 1)).to be(true)
      expect(described_class.space_at?("a\bb", 1)).to be(false)
      expect(described_class.space_at?("a!b", 1)).to be(false)
      expect(described_class.space_at?("a~b", 1)).to be(false)
    end

    it "matches a character outside ASCII as a whole" do
      expect(described_class.space_at?("a\u00A0b", 1)).to be(true)
      expect(described_class.space_at?("a\u2003b", 1)).to be(true)
      expect(described_class.space_at?("a\u3000b", 1)).to be(true)
      expect(described_class.space_at?("a\u2003\u2003", 1)).to be(true)
      expect(described_class.space_at?("aéb", 1)).to be(false)
      expect(described_class.space_at?("a漢b", 1)).to be(false)
      expect(described_class.space_at?("a😀b", 1)).to be(false)
    end

    it "is false past the end and for no index" do
      expect(described_class.space_at?("a", 1)).to be(false)
      expect(described_class.space_at?("a", nil)).to be(false)
    end
  end

  describe ".last_char_index" do
    it "finds the start of the last character" do
      expect(described_class.last_char_index("ab")).to eq(1)
      expect(described_class.last_char_index("aé")).to eq(1)
      expect(described_class.last_char_index("a漢")).to eq(1)
      expect(described_class.last_char_index("a😀")).to eq(1)
      expect(described_class.last_char_index("😀")).to eq(0)
      expect(described_class.last_char_index("a")).to eq(0)
      expect(described_class.last_char_index("")).to be_nil
    end
  end

  describe ".visible?" do
    it "is true for a character that is not whitespace" do
      expect(described_class.visible?("a")).to be(true)
      expect(described_class.visible?(" a")).to be(true)
      expect(described_class.visible?("\u00A0é")).to be(true)
      expect(described_class.visible?("  \u2003漢 ")).to be(true)
    end

    it "is false for whitespace alone and for nothing" do
      expect(described_class.visible?("")).to be(false)
      expect(described_class.visible?(" \t\n")).to be(false)
      expect(described_class.visible?("\u00A0\u2003\u3000")).to be(false)
      expect(described_class.visible?(" \u00A0 ")).to be(false)
    end
  end
end
