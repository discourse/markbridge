# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Inline
        # What has to happen where two pieces of inline Markdown meet. The
        # rules are a table read from the class of the byte in front of
        # the join and the byte after it, so the common case, nothing to
        # do, costs four byte reads and no method call.
        #
        # A run of emphasis delimiters at the start of the piece cannot
        # open when a word character stands in front of it and
        # punctuation follows it: `item*\#*` stays literal text
        # (CommonMark 6.2). The mirror image holds for a run at the end
        # of the buffer. An empty HTML comment between the two sides is
        # punctuation, so the run can open or close again. Two runs of
        # the same delimiter would merge into one longer run, the
        # comment keeps them apart. A `!` right in front of a link makes
        # it an image, a backslash keeps it a `!`.
        #
        # Two more joins are what the escaper would escape inside one
        # text, but cannot see across two pieces: a `<` at the end of the
        # buffer with a `!`, `?`, `/` or a letter after it would start raw
        # HTML (a declaration like `<!y` eats the text up to the next
        # `>`), so the `<` gets a backslash; two `-` that meet would be a
        # dash to Discourse's typographer, so the second gets one.
        module Joins
          # Inserted between two pieces. Invisible when cooked, and
          # punctuation to the flanking rules.
          BOUNDARY_COMMENT = "<!---->"

          # A punctuation character or a symbol right at the search start,
          # which is what CommonMark's flanking rules count as punctuation
          # (ASCII and Unicode alike), as markdown-it does. For a character
          # outside ASCII only; an ASCII byte is answered from the class
          # table without a regex.
          PUNCTUATION_AT = /\A[\p{P}\p{S}]/
          # Whitespace outside ASCII, matched on the one character.
          SPACE_AT = /\A[[:space:]]/
          BACKSLASH = 92
          SPACE = 32
          TAB = 9
          CR = 13

          # What a byte is to the join rules. WORD: ASCII letters and
          # digits, and every non-ASCII byte. On the side of the join away
          # from a delimiter run, Unicode punctuation then goes through the
          # check like a letter, which at worst costs a comment that
          # changes nothing; on the side of the run the check reads the
          # whole character (.punctuation_at?). PUNCTUATION: ASCII
          # punctuation as CommonMark defines it, the backslash included,
          # which is what makes an escaped character at the edge of an
          # emphasis count as punctuation. The five bytes the rules name
          # get a class of their own, so a class tells them apart without
          # a second comparison; they stay punctuation, which is why they
          # sit above PUNCTUATION. AT is the `@` of a mention: after a word
          # character, or punctuation that an email address may hold, it
          # would read as an email address with the text after it. LT and
          # DASH are the `<` and the `-` that the escaper would escape
          # inside one text, see the module comment.
          OTHER = 0
          WORD = 1
          PUNCTUATION = 2
          BANG = 3
          BRACKET = 4
          BACKTICK = 5
          STAR = 6
          UNDERSCORE = 7
          TILDE = 8
          AT = 9
          LT = 10
          DASH = 11
          CLASS_COUNT = 12
          # A 256-byte string read with getbyte, so classifying a byte is
          # one read instead of a chain of comparisons.
          BYTE_CLASSES =
            Array
              .new(256) do |byte|
                case byte
                when 33
                  BANG
                when 42
                  STAR
                when 45
                  DASH
                when 60
                  LT
                when 64
                  AT
                when 91
                  BRACKET
                when 95
                  UNDERSCORE
                when 96
                  BACKTICK
                when 126
                  TILDE
                else
                  if byte >= 128 || byte.between?(48, 57) || byte.between?(65, 90) ||
                       byte.between?(97, 122)
                    WORD
                  elsif byte.between?(33, 47) || byte.between?(58, 64) || byte.between?(91, 96) ||
                        byte.between?(123, 126)
                    PUNCTUATION
                  else
                    OTHER
                  end
                end
              end
              .pack("C*")
              .freeze

          # What a join between two pieces has to do. ESCAPE_BEFORE puts a
          # backslash in front of the last byte of the buffer (a `!` or a
          # `<`), ESCAPE_AFTER one in front of the first byte of the piece
          # (a `-`).
          NOTHING = 0
          BOUNDARY = 1
          CHECK_AFTER = 2
          CHECK_BEFORE = 3
          ESCAPE_BEFORE = 4
          ESCAPE_AFTER = 5
          # Runs that merge into a single longer run during Markdown
          # parsing: emphasis (* _), strikethrough (~), code spans (`).
          MERGING_CLASSES = [STAR, UNDERSCORE, TILDE, BACKTICK].freeze
          # Runs that open and close only where the flanking rules allow it.
          FLANKING_CLASSES = [STAR, UNDERSCORE, TILDE].freeze
          # The bytes after a `<` that start raw HTML (CommonMark 6.6): a
          # tag name or `/`, a declaration `!`, a processing instruction
          # `?`. Bytes, not classes: a digit or a non-ASCII byte is a word
          # character too, but starts no tag.
          HTML_START_BYTES = [33, 47, 63, *65..90, *97..122].freeze

          # The action per join, in CLASS_COUNT rows of 256 bytes (2304 in
          # all), read with JOIN_ACTIONS.getbyte((class of the byte in front
          # << 8) + the byte after). Both sides of a join are a single byte
          # for every rule, so the whole decision fits in the table except
          # for the two cases that have to look past a delimiter run and the
          # one that has to count backslashes.
          #
          # A `_` run never opens after, or closes in front of, a word
          # character, so it needs no look past the run.
          #
          # A tilde counts as a blocking neighbor like a word character:
          # CommonMark reads `~` as punctuation, but cmark-gfm does not
          # treat it as one next to an emphasis delimiter, so strikethrough
          # right next to emphasis with a punctuation edge needs the
          # boundary as well. markdown-it would not need it; the comment
          # changes nothing there.
          JOIN_ACTIONS =
            Array
              .new(CLASS_COUNT * 256) do |index|
                before = index >> 8
                byte = index & 255
                after = BYTE_CLASSES.getbyte(byte)

                if before == after && MERGING_CLASSES.include?(before)
                  BOUNDARY
                elsif before == BANG && after == BRACKET
                  ESCAPE_BEFORE
                elsif before == LT && HTML_START_BYTES.include?(byte)
                  ESCAPE_BEFORE
                elsif before == DASH && after == DASH
                  ESCAPE_AFTER
                elsif FLANKING_CLASSES.include?(after) && (before == WORD || before == TILDE)
                  after == UNDERSCORE ? BOUNDARY : CHECK_AFTER
                elsif FLANKING_CLASSES.include?(before) && (after == WORD || after == TILDE)
                  before == UNDERSCORE ? BOUNDARY : CHECK_BEFORE
                elsif after == AT && before != OTHER
                  BOUNDARY
                else
                  NOTHING
                end
              end
              .pack("C*")
              .freeze
          private_constant :PUNCTUATION_AT,
                           :SPACE_AT,
                           :BACKSLASH,
                           :SPACE,
                           :TAB,
                           :CR,
                           :OTHER,
                           :WORD,
                           :PUNCTUATION,
                           :BANG,
                           :BRACKET,
                           :BACKTICK,
                           :STAR,
                           :UNDERSCORE,
                           :TILDE,
                           :AT,
                           :LT,
                           :DASH,
                           :CLASS_COUNT,
                           :BYTE_CLASSES,
                           :NOTHING,
                           :BOUNDARY,
                           :CHECK_AFTER,
                           :CHECK_BEFORE,
                           :ESCAPE_BEFORE,
                           :ESCAPE_AFTER,
                           :MERGING_CLASSES,
                           :FLANKING_CLASSES,
                           :HTML_START_BYTES,
                           :JOIN_ACTIONS

          # Appends +piece+ to +buffer+ with what the join between them
          # needs. On an empty buffer getbyte returns nil and there is no
          # byte in front of the join, so the first piece needs no guard
          # of its own.
          #
          # @param buffer [String] the Markdown written so far, changed in place
          # @param piece [String] the next piece, not empty
          # @return [String] +buffer+
          def self.append(buffer, piece)
            last_byte = buffer.getbyte(-1)
            if last_byte
              action =
                JOIN_ACTIONS.getbyte((BYTE_CLASSES.getbyte(last_byte) << 8) + piece.getbyte(0))
              join(buffer, piece, last_byte, action) unless action == NOTHING
            end
            buffer << piece
          end

          # Appends +piece+ to +buffer+ with the join that +like+ would need
          # in its place: +like+ is the text a later step will most likely
          # put there instead of +piece+ (see Tokens.placeholder). +before+,
          # when given, stands in the same way for the end of the buffer,
          # after a placeholder; then a `!` at its end can't take a
          # backslash, and the boundary comment keeps it from making an
          # image of a link instead.
          #
          # @param buffer [String] changed in place
          # @param piece [String] the next piece, not empty
          # @param like [String, nil] stands in for +piece+, nil for none
          # @param before [String, nil] stands in for the end of +buffer+
          # @return [String] +buffer+
          def self.append_like(buffer, piece, like, before = nil)
            tail = before || buffer
            last_byte = tail.getbyte(-1)
            if last_byte
              after = like || piece
              action =
                JOIN_ACTIONS.getbyte((BYTE_CLASSES.getbyte(last_byte) << 8) + after.getbyte(0))
              join(buffer, after, last_byte, action, tail, !like.nil?) unless action == NOTHING
            end
            buffer << piece
          end

          # Whether the last character of +string+ is escaped: only an odd
          # run of backslashes in front of it escapes it, `\\!` is an
          # escaped backslash followed by an active `!`. When the run
          # reaches the start of the string the index turns negative and
          # getbyte wraps around to the last character, which is no
          # backslash and stops the loop.
          #
          # @param string [String] not empty
          # @return [Boolean]
          def self.escaped_end?(string)
            escaped = false
            index = string.bytesize - 2
            while string.getbyte(index) == BACKSLASH
              escaped = !escaped
              index -= 1
            end
            escaped
          end

          # Carries out the action the table picked. NOTHING never gets
          # here, the caller keeps it out, so the last branch is
          # ESCAPE_BEFORE. +tail+ is what the end of the buffer is read
          # as, and +stand_in+ says whether +piece+ stands for the piece
          # that is appended, see .append_like: a stand-in gets no
          # backslash, the comment keeps the two apart instead.
          def self.join(buffer, piece, last_byte, action, tail = buffer, stand_in = false)
            if action == BOUNDARY
              buffer << BOUNDARY_COMMENT
            elsif action == CHECK_AFTER
              buffer << BOUNDARY_COMMENT if punctuation_at?(piece, after_run(piece))
            elsif action == CHECK_BEFORE
              buffer << BOUNDARY_COMMENT if punctuation_at?(tail, before_run(tail, last_byte))
            elsif action == ESCAPE_AFTER
              buffer << (stand_in ? BOUNDARY_COMMENT : "\\")
            elsif !tail.equal?(buffer)
              buffer << BOUNDARY_COMMENT
            elsif !escaped_end?(buffer)
              # Byte offsets: the `!` or `<` is the last byte.
              buffer.bytesplice(buffer.bytesize - 1, 0, "\\")
            end
          end

          # The byte offset of the first byte after the run of the piece's
          # first byte, nil when the piece is the run alone. A delimiter is
          # ASCII, so the byte after the run starts a character.
          def self.after_run(piece)
            run = piece.getbyte(0)
            index = 1
            index += 1 while piece.getbyte(index) == run
            index if index < piece.bytesize
          end

          # The byte offset of the character in front of the run that ends
          # the buffer, nil when the buffer is the run alone. The byte in
          # front of the run may be inside a multi-byte character, so the
          # search goes back to its first byte.
          def self.before_run(buffer, run)
            index = buffer.bytesize - 2
            index -= 1 while index >= 0 && buffer.getbyte(index) == run
            return if index.negative?

            index -= 1 while index.positive? && (buffer.getbyte(index) & 0xC0) == 0x80
            index
          end

          # Whether the character at byte +index+ of +string+ is punctuation
          # for the flanking rules; nil is no character and no punctuation.
          # An ASCII byte is answered from the class table, a character
          # outside ASCII is matched as a whole.
          def self.punctuation_at?(string, index)
            return false if index.nil?

            byte = string.getbyte(index)
            return BYTE_CLASSES.getbyte(byte) >= PUNCTUATION if byte < 128

            string.byteslice(index, char_length(byte)).match?(PUNCTUATION_AT)
          end

          # Whether the character at byte +index+ of +string+ is whitespace
          # as [[:space:]] reads it; nil is no character. A regex over the
          # whole string would scan it for its encoding first, which costs
          # as much as the string is long.
          def self.space_at?(string, index)
            return false if index.nil?

            byte = string.getbyte(index)
            return false if byte.nil?
            return byte == SPACE || (byte >= TAB && byte <= CR) if byte < 128
            return false if byte < 0xC2

            string.byteslice(index, char_length(byte)).match?(SPACE_AT)
          end

          # The byte offset of the last character of +string+, nil for an
          # empty string.
          def self.last_char_index(string)
            index = string.bytesize - 1
            index -= 1 while index.positive? && (string.getbyte(index) & 0xC0) == 0x80
            index.negative? ? nil : index
          end

          # Whether +string+ holds a character that is not whitespace.
          def self.visible?(string)
            index = 0
            while (byte = string.getbyte(index))
              return true unless space_at?(string, index)

              index += byte < 128 ? 1 : char_length(byte)
            end
            false
          end

          # The length in bytes of the character whose lead byte is +byte+.
          # A slice that reaches into the next character is no valid
          # string, so a slice is cut to the character.
          def self.char_length(byte)
            if byte >= 0xF0
              4
            elsif byte >= 0xE0
              3
            else
              2
            end
          end

          private_class_method :join, :punctuation_at?, :after_run, :before_run, :char_length
        end
      end
    end
  end
end
