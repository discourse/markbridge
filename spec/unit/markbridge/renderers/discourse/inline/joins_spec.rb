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
      }
    end

    let(:action_names) do
      {
        described_class.const_get(:NOTHING) => :nothing,
        described_class.const_get(:BOUNDARY) => :boundary,
        described_class.const_get(:CHECK_AFTER) => :check_after,
        described_class.const_get(:CHECK_BEFORE) => :check_before,
        described_class.const_get(:ESCAPE_BANG) => :escape_bang,
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

      if before == after && merging.include?(before)
        :boundary
      elsif before == "!".ord && after == "[".ord
        :escape_bang
      elsif flanking.include?(after) && blocking?(before)
        after == "_".ord ? :boundary : :check_after
      elsif flanking.include?(before) && blocking?(after)
        before == "_".ord ? :boundary : :check_before
      else
        :nothing
      end
    end

    it "gives every class a number of its own" do
      expect(class_names.size).to eq(described_class.const_get(:CLASS_COUNT))
    end

    it "gives every action a number of its own" do
      expect(action_names.size).to eq(5)
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
      names = %i[punctuation bang bracket backtick star underscore tilde]
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
end
