# frozen_string_literal: true

RSpec.describe Markbridge::Renderers::Discourse::Inline::Serializer do
  subject(:serializer) do
    described_class.new(escaper: Markbridge::Renderers::Discourse::MarkdownEscaper.new)
  end

  let(:tokens) { Markbridge::Renderers::Discourse::Inline::Tokens }

  def write(*tokens, html_mode: false)
    serializer.write(tokens, html_mode:)
  end

  def em(*content)
    [tokens.open(:em), *content, tokens.close(:em)]
  end

  describe "#write" do
    it "writes nothing for no tokens" do
      expect(write).to eq("")
    end

    it "writes Markdown when html_mode is not given" do
      expect(serializer.write([tokens.open(:em), tokens.text("a"), tokens.close(:em)])).to eq("*a*")
    end

    it "names an unknown token in the error" do
      expect { write(:nope) }.to raise_error(ArgumentError, "unknown inline token :nope")
    end

    it "goes on with the token after a link" do
      expect(
        write(tokens.link_open("u"), tokens.text("x"), tokens.link_close, tokens.text("y")),
      ).to eq("[x](u)y")
    end

    it "escapes text" do
      expect(write(tokens.text("# a *b*"))).to eq("\\# a \\*b\\*")
    end

    it "escapes text in a link label with the closing bracket" do
      expect(write(tokens.text("a]b", tokens::LABEL))).to eq("a]b".sub("]", "\\]"))
    end

    it "writes verbatim text as it is" do
      expect(write(tokens.text("*a*", tokens::VERBATIM))).to eq("*a*")
    end

    it "writes raw Markdown and HTML as they are" do
      expect(write(tokens.raw("**a**"), tokens.html("<sup>2</sup>"))).to eq("**a**<sup>2</sup>")
    end

    it "joins the pieces with the join rules" do
      expect(write(tokens.raw("**a**"), tokens.raw("**b**"))).to eq("**a**<!---->**b**")
    end

    it "writes a hard break as a newline, and as <br> on a line that holds only whitespace" do
      expect(write(tokens.text("a"), tokens.hard_break, tokens.text("b"))).to eq("a\nb")
      expect(write(tokens.hard_break, tokens.text("b"))).to eq("\nb")
      expect(write(tokens.text("a"), tokens.hard_break, tokens.hard_break, tokens.text("b"))).to eq(
        "a\n<br>b",
      )
      expect(write(tokens.text("a\n \t"), tokens.hard_break, tokens.text("b"))).to eq("a\n \t<br>b")
      expect(write(tokens.text("a\n\u00A0"), tokens.hard_break, tokens.text("b"))).to eq(
        "a\n\u00A0\nb",
      )
      expect(
        write(tokens.text("a\n"), *em(tokens.text(" "), tokens.hard_break, tokens.text("b"))),
      ).to eq("a\n <br>*b*")
      expect(write(tokens.text("a"), *em(tokens.hard_break, tokens.text("b")))).to eq("a\n*b*")
    end

    it "writes a newline at the start of the text after a hard break as <br>" do
      expect(write(tokens.text("x"), tokens.hard_break, "\ny")).to eq("x\n<br>y")
      expect(write(tokens.text("x"), tokens.hard_break, tokens.text("\n"), "a")).to eq("x\n<br>a")
      # The newline at the edge of the emphasis stands outside the markers.
      expect(write(tokens.text("x"), tokens.hard_break, *em("\ny"))).to eq("x\n<br>*y*")
      expect(write(*em(tokens.text("x"), tokens.hard_break, "\ny"))).to eq("*x\n<br>y*")
      expect(write(*em(tokens.text("x"), tokens.hard_break), "\ny")).to eq("*x*\n<br>y")
      # A break at the end of a link label moves out of the label too.
      link = [tokens.link_open("u"), tokens.text("x"), tokens.hard_break, tokens.link_close]
      expect(write(*link, "\ny")).to eq("[x](u)\n<br>y")
      # A newline at the end of the content is no break.
      expect(write(*em(tokens.text("x\n")), "\ny")).to eq("*x*\n\ny")
      expect(write(tokens.link_open("u"), tokens.text("x\n"), tokens.link_close, "\ny")).to eq(
        "[x](u)\n\ny",
      )
      # Two newlines are a blank line the text brings on purpose.
      expect(write(tokens.text("x"), tokens.hard_break, "\n\ny")).to eq("x\n\n\ny")
      # A newline after anything but a hard break is a break of its own.
      expect(write(tokens.text("x\n"), "\ny")).to eq("x\n\ny")
      expect(write(tokens.text("x"), tokens.hard_break, "a", "\ny")).to eq("x\na\ny")
      expect(
        write(tokens.text("x"), tokens.hard_break, tokens.bare_url("https://e.com/"), "\ny"),
      ).to eq("x\nhttps://e.com/\ny")
    end

    it "writes <br> for a break on a line that holds nothing else, also at the start" do
      expect(write(tokens.hard_break, tokens.hard_break, tokens.text("b"))).to eq("\n<br>b")
    end

    it "takes a <br> at the end of the run off again" do
      # Nothing follows, so the <br> protects no line.
      expect(write(tokens.text("a"), tokens.hard_break, tokens.hard_break)).to eq("a\n")
      expect(write(tokens.hard_break, tokens.hard_break)).to eq("\n")
      expect(write(tokens.text("a\n"), tokens.hard_break, tokens.text(" "))).to eq("a\n<br> ")
      expect(write(tokens.text("a\n"), tokens.hard_break, html_mode: true)).to eq("a\n<br>")
    end

    it "writes a break or a newline right after an HTML tag as <br>" do
      # The tag alone on its line would open an HTML block.
      expect(write(tokens.html("<sup>"), tokens.hard_break, "a", tokens.html("</sup>"))).to eq(
        "<sup><br>a</sup>",
      )
      expect(write(tokens.html("<sup>"), tokens.text("\na"), tokens.html("</sup>"))).to eq(
        "<sup><br>a</sup>",
      )
      # Two newlines are a blank line the text brings on purpose.
      expect(write(tokens.html("<sup>"), tokens.text("\n\na"))).to eq("<sup>\n\na")
      expect(write(tokens.html("<sup>"), "x", tokens.hard_break, "a")).to eq("<sup>x\na")
    end

    it "does not take a newline at the start of the text after a <br> for a break" do
      # The break was written as <br>, so the newline makes no blank line.
      expect(write(tokens.text("a"), tokens.hard_break, tokens.hard_break, "\ny")).to eq(
        "a\n<br>\ny",
      )
    end

    it "writes nothing for a hard break after a blank line" do
      expect(write(tokens.text("a\n\n"), tokens.hard_break, tokens.text("b"))).to eq("a\n\nb")
      expect(write(tokens.text("a\n \n\t"), tokens.hard_break, tokens.text("b"))).to eq("a\n \n\tb")
      expect(
        write(tokens.text("a\n"), *em(tokens.text(" \n"), tokens.hard_break, tokens.text("b"))),
      ).to eq("a\n \n*b*")
      expect(write(tokens.text("a\n\n"), *em(tokens.hard_break, tokens.text("b")))).to eq(
        "a\n\n*b*",
      )
    end

    it "writes no markers around nothing but whitespace and <br>" do
      expect(write(*em(tokens.hard_break, "<br>"), "a")).to eq("\n<br>a")
      expect(write(*em("<br>"))).to eq("<br>")
      expect(write(*em("<br>", tokens.text(" ")))).to eq("<br> ")
      expect(write(*em(tokens.text(" "), "<br>"))).to eq(" <br>")
      expect(write(*em(tokens.text(" "), "<br>", tokens.text(" ")))).to eq(" <br> ")
    end

    it "keeps the spaces at the start of a piece after a blank line in html_mode" do
      expect(write("a\n\n", "   b", html_mode: true)).to eq("a\n\n   b")
    end

    it "keeps the spaces at the start of a piece after a waiting bare URL" do
      href = "https://example.com/"

      expect(write("a\n\n", tokens.bare_url(href), "   b")).to eq("a\n\n#{href}   b")
    end

    it "takes the spaces at the start of a piece after a blank line off" do
      expect(write("a\n\n", "   ", "b")).to eq("a\n\nb")
      expect(write("a\n \n", "   b")).to eq("a\n \nb")
      expect(write("a\n\n", " \t b")).to eq("a\n\nb")
      expect(write("a\n\n", "\tb")).to eq("a\n\nb")
      expect(write("a\n\n", tokens.text(" \n "), "b")).to eq("a\n\n\n b")
      expect(write("a\n\n", "\u00A0b")).to eq("a\n\n\u00A0b")
      expect(write("a\n", "   ", "b")).to eq("a\n   b")
      expect(write("a\n\n", *em(tokens.text(" b")))).to eq("a\n\n*b*")
      # The blank lines of the outer buffer count inside a nested run too.
      expect(write("a\n", *em(tokens.text(" \n"), tokens.hard_break, tokens.text(" b")))).to eq(
        "a\n \n*b*",
      )
    end

    describe "delimiters" do
      it "wraps the content in the markers" do
        expect(write(tokens.open(:strong), tokens.text("a"), tokens.close(:strong))).to eq("**a**")
        expect(write(*em(tokens.text("a")))).to eq("*a*")
        expect(write(tokens.open(:s), tokens.text("a"), tokens.close(:s))).to eq("~~a~~")
        expect(write(tokens.open(:u), tokens.text("a"), tokens.close(:u))).to eq("[u]a[/u]")
      end

      it "keeps whitespace at the edges outside the markers" do
        expect(write(*em(tokens.text("  a\t")))).to eq("  *a*\t")
        expect(write(*em(tokens.text(" a ")))).to eq(" *a* ")
        expect(write(*em(tokens.text(" a\nb ")))).to eq(" *a\nb* ")
      end

      it "keeps a <br> at the edges outside the markers" do
        expect(
          write(tokens.text("a"), tokens.hard_break, *em(tokens.hard_break, tokens.text("b"))),
        ).to eq("a\n<br>*b*")
        expect(write(*em(tokens.text("b"), tokens.html("<br>")))).to eq("*b*<br>")
        expect(write(*em(tokens.html("<br> "), tokens.text("b")))).to eq("<br> *b*")
      end

      it "keeps an escaped <br> in the text inside the markers" do
        expect(write(*em(tokens.text("<br>b")))).to eq("*\\<br>b*")
      end

      it "keeps whitespace on one edge outside the markers" do
        expect(write(*em(tokens.text("  a")))).to eq("  *a*")
        expect(write(*em(tokens.text("a  ")))).to eq("*a*  ")
      end

      it "writes content with nothing visible without markers" do
        expect(write(*em(tokens.text("  ")))).to eq("  ")
        expect(write(*em(tokens.text(" ")))).to eq(" ")
        expect(write(*em)).to eq("")
      end

      it "joins the pieces of the content among themselves" do
        expect(write(*em(tokens.raw("`a`"), tokens.raw("`b`")))).to eq("*`a`<!---->`b`*")
      end

      it "joins the wrapped content with its neighbors" do
        expect(write(tokens.text("item"), *em(tokens.text("#")))).to eq("item<!---->*\\#*")
        expect(write(*em(tokens.text("#")), tokens.text("item"))).to eq("*\\#*<!---->item")
      end

      it "nests a delimiter in another and falls back to HTML when the markers share a character" do
        strong = tokens.open(:strong), tokens.text("b"), tokens.close(:strong)
        strike = tokens.open(:s), tokens.text("b"), tokens.close(:s)

        expect(write(*em(tokens.text("a"), *strike, tokens.text("c")))).to eq("*a~~b~~c*")
        expect(write(*em(tokens.text("a"), *strong, tokens.text("c")))).to eq("<em>a**b**c</em>")
      end

      it "nests a delimiter in itself" do
        expect(write(*em(tokens.text("a "), *em(tokens.text("b"))))).to eq("<em>a *b*</em>")
      end

      it "falls back to HTML when the content holds the marker" do
        expect(write(tokens.open(:strong), tokens.raw("a**b"), tokens.close(:strong))).to eq(
          "<strong>a**b</strong>",
        )
        expect(write(*em(tokens.raw("a*b")))).to eq("<em>a*b</em>")
        expect(write(tokens.open(:s), tokens.raw("a~~b"), tokens.close(:s))).to eq("<s>a~~b</s>")
      end

      it "falls back to HTML when the marker's character stands at an edge of the content" do
        expect(write(tokens.open(:strong), tokens.raw("*a"), tokens.close(:strong))).to eq(
          "<strong>*a</strong>",
        )
        expect(write(tokens.open(:strong), tokens.raw("a*"), tokens.close(:strong))).to eq(
          "<strong>a*</strong>",
        )
        expect(
          write(tokens.open(:strong), tokens.text("a"), tokens.html("*"), tokens.close(:strong)),
        ).to eq("<strong>a*</strong>")
        expect(write(tokens.open(:s), tokens.raw("a~"), tokens.close(:s))).to eq("<s>a~</s>")
        expect(write(tokens.open(:s), tokens.raw(" ~a "), tokens.close(:s))).to eq(" <s>~a</s> ")
      end

      it "wraps emphasis with a nested pair at one edge and falls back with pairs at both edges" do
        inner = ->(text) { [tokens.open(:em), tokens.text(text), tokens.close(:em)] }

        expect(
          write(tokens.open(:strong), *inner.call("a"), tokens.text(" b"), tokens.close(:strong)),
        ).to eq("***a* b**")
        expect(
          write(tokens.open(:strong), tokens.text("a "), *inner.call("b"), tokens.close(:strong)),
        ).to eq("**a *b***")
        expect(
          write(tokens.open(:strong), *inner.call("a"), *inner.call(".y"), tokens.close(:strong)),
        ).to eq("<strong>*a*<!---->*.y*</strong>")
      end

      it "sees one pair spanning the content through a pair of the same kind inside it" do
        inner = [
          tokens.open(:em),
          tokens.open(:em),
          tokens.text("a"),
          tokens.close(:em),
          tokens.close(:em),
        ]

        expect(write(tokens.open(:strong), *inner, tokens.close(:strong))).to eq("**<em>*a*</em>**")
      end

      it "wraps emphasis with one nested pair spanning the content, not a bare marker character" do
        inner = [tokens.open(:em), tokens.text("a"), tokens.close(:em)]

        expect(write(tokens.open(:strong), *inner, tokens.close(:strong))).to eq("***a***")
        expect(write(tokens.open(:strong), tokens.raw("*a"), tokens.close(:strong))).to eq(
          "<strong>*a</strong>",
        )
        expect(write(tokens.open(:strong), *inner, tokens.raw(" b*"), tokens.close(:strong))).to eq(
          "<strong>*a* b*</strong>",
        )
      end

      it "keeps whitespace at the edges inside the BBCode underline" do
        expect(write(tokens.open(:u), tokens.text(" a "), tokens.close(:u))).to eq("[u] a [/u]")
      end

      it "falls back to HTML for strikethrough with a raw tilde at an edge" do
        expect(write(tokens.open(:s), tokens.raw("~a"), tokens.close(:s))).to eq("<s>~a</s>")
      end

      it "falls back to HTML for strikethrough with a nested strikethrough at an edge" do
        inner = [tokens.open(:s), tokens.text("a"), tokens.close(:s)]

        expect(write(tokens.open(:s), *inner, tokens.close(:s))).to eq("<s>~~a~~</s>")
        expect(write(tokens.open(:s), *inner, tokens.text(" b"), tokens.close(:s))).to eq(
          "<s>~~a~~ b</s>",
        )
      end

      it "falls back to HTML for strikethrough with a nested tilde pair at an edge" do
        inner = [tokens.open(:s), tokens.text("a"), tokens.close(:s)]

        expect(write(tokens.open(:s), *inner, tokens.text(" b"), tokens.close(:s))).to eq(
          "<s>~~a~~ b</s>",
        )
      end

      it "keeps whitespace at the edges outside the HTML fallback too" do
        strong = [tokens.open(:strong), tokens.text("a"), tokens.close(:strong)]

        expect(
          write(tokens.open(:strong), tokens.hard_break, *strong, tokens.close(:strong)),
        ).to eq("\n<strong>**a**</strong>")
      end

      it "keeps a backslash in front of trailing whitespace from escaping the closing marker" do
        expect(write(tokens.open(:strong), tokens.raw("a\\ "), tokens.close(:strong))).to eq(
          "**a\\\\** ",
        )
        expect(write(tokens.open(:strong), tokens.raw("a\\\\ "), tokens.close(:strong))).to eq(
          "**a\\\\** ",
        )
        expect(write(tokens.link_open("/a"), tokens.raw("x\\ "), tokens.link_close)).to eq(
          "[x\\\\](/a) ",
        )
      end

      it "escapes a colon right after a BBCode opening tag" do
        expect(write(tokens.open(:u), tokens.text(":y"), tokens.close(:u))).to eq("[u]\\:y[/u]")
        expect(write(*em(tokens.text(":y")))).to eq("*:y*")
      end

      it "wraps content whose last character is escaped" do
        expect(write(tokens.open(:strong), tokens.text("*bold*"), tokens.close(:strong))).to eq(
          "**\\*bold\\***",
        )
        expect(write(tokens.open(:s), tokens.raw("a\\\\~"), tokens.close(:s))).to eq(
          "<s>a\\\\~</s>",
        )
        expect(write(tokens.open(:s), tokens.raw("\\~"), tokens.close(:s))).to eq("~~\\~~~")
      end

      describe "content with a blank line" do
        def strong(*content)
          [tokens.open(:strong), *content, tokens.close(:strong)]
        end

        it "wraps every paragraph in its own markers" do
          expect(write(*strong(tokens.text("a\n\nb")))).to eq("**a**\n\n**b**")
          expect(write(tokens.open(:u), tokens.text("a\n\nb"), tokens.close(:u))).to eq(
            "[u]a[/u]\n\n[u]b[/u]",
          )
        end

        it "keeps a blank line at an edge outside the markers" do
          expect(write(*strong(tokens.text("a\n\n")))).to eq("**a**\n\n")
          expect(write(tokens.text("x "), *strong(tokens.raw("\n\na")))).to eq("x \n\n**a**")
        end

        it "writes a paragraph with nothing visible without markers" do
          expect(write(*strong(tokens.text("a\n\n  \n\nb")))).to eq("**a**\n\n  \n\n**b**")
        end

        it "keeps whitespace at the edges of every paragraph outside the markers" do
          expect(write(*em(tokens.text("a \n\n b")))).to eq("*a* \n\n *b*")
        end

        it "picks the HTML fallback for every paragraph on its own" do
          expect(write(tokens.open(:s), tokens.raw("a~\n\nb"), tokens.close(:s))).to eq(
            "<s>a~</s>\n\n~~b~~",
          )
          expect(write(tokens.open(:s), tokens.raw("a\n\n~b"), tokens.close(:s))).to eq(
            "~~a~~\n\n<s>~b</s>",
          )
        end

        it "keeps a nested pair at the start or the end of the content at that edge" do
          expect(write(*strong(*em(tokens.text("a")), tokens.text(" b\n\nc")))).to eq(
            "***a* b**\n\n**c**",
          )
          expect(write(*strong(tokens.text("a\n\nb "), *em(tokens.text("c"))))).to eq(
            "**a**\n\n**b *c***",
          )
        end

        it "falls back to HTML for a marker character at the outer edges without a nested pair" do
          expect(write(*strong(tokens.raw("*a\n\nb")))).to eq("<strong>*a</strong>\n\n**b**")
          expect(write(*strong(tokens.raw("a\n\nb*")))).to eq("**a**\n\n<strong>b*</strong>")
        end

        it "takes a split nested pair at the edges between the paragraphs as a pair" do
          expect(
            write(*strong(tokens.text("a"), *em(tokens.text("b\n\nc")), tokens.text("d"))),
          ).to eq("**a*b***\n\n***c*d**")
        end

        it "falls back to HTML for a paragraph with pairs at both edges that do not span it" do
          expect(
            write(
              *strong(*em(tokens.text("a\n\nb")), tokens.text(" "), *em(tokens.text("c\n\nd"))),
            ),
          ).to eq("<strong>*a*</strong>\n\n<strong>*b* *c*</strong>\n\n<strong>*d*</strong>")
        end

        it "takes a nested pair that spans the content as spanning every paragraph" do
          expect(write(*strong(*em(tokens.text("a\n\nb"))))).to eq("***a***\n\n***b***")
        end

        it "wraps content with a code fence as a whole" do
          expect(write(*strong(tokens.raw("a\n\n```\nx\n```")))).to eq("**a\n\n```\nx\n```**")
        end

        it "writes the HTML tags around the whole content in an HTML block" do
          expect(write(*strong(tokens.raw("a\n\nb")), html_mode: true)).to eq(
            "<strong>a\n\nb</strong>",
          )
        end
      end

      it "has no HTML fallback for the underline" do
        expect(write(tokens.open(:u), tokens.raw("[u]a[/u]"), tokens.close(:u))).to eq(
          "[u][u]a[/u][/u]",
        )
      end
    end

    describe "code spans" do
      it "writes nothing for empty code" do
        expect(write(tokens.code(""))).to eq("")
      end

      it "wraps the code in one backtick more than its longest run" do
        expect(write(tokens.code("a"))).to eq("`a`")
        expect(write(tokens.code("a`b"))).to eq("``a`b``")
        expect(write(tokens.code("a``b`c"))).to eq("```a``b`c```")
        expect(write(tokens.code("a`b``c"))).to eq("```a`b``c```")
      end

      it "pads code with a backtick at an edge" do
        expect(write(tokens.code("`a"))).to eq("`` `a ``")
        expect(write(tokens.code("a`"))).to eq("`` a` ``")
      end

      it "pads code with a space at both edges" do
        expect(write(tokens.code(" a "))).to eq("`  a  `")
      end

      it "does not pad code with a space at one edge, or spaces only" do
        expect(write(tokens.code(" a"))).to eq("` a`")
        expect(write(tokens.code("a "))).to eq("`a `")
        expect(write(tokens.code("  "))).to eq("`  `")
      end

      it "does not escape the code" do
        expect(write(tokens.code("*a*"))).to eq("`*a*`")
      end

      it "keeps two code spans apart" do
        expect(write(tokens.code("a"), tokens.code("b"))).to eq("`a`<!---->`b`")
      end
    end

    describe "placeholders" do
      def placeholder(like = "https://e.com/t/17", text = "[link|17]")
        tokens.placeholder(text, like:)
      end

      def strong(*content)
        [tokens.open(:strong), *content, tokens.close(:strong)]
      end

      it "writes the placeholder text as it is" do
        expect(write(tokens.text("see "), placeholder)).to eq("see [link|17]")
        expect(write(placeholder("x", "*a* [b]"))).to eq("*a* [b]")
      end

      it "joins a closing marker in front of it as if like stood there" do
        expect(write(*strong(tokens.text("a.")), placeholder)).to eq("**a.**<!---->[link|17]")
      end

      it "joins an opening marker after it as if like stood there" do
        expect(write(placeholder, *strong(tokens.text(".a")))).to eq("[link|17]<!---->**.a**")
        expect(write(placeholder("https://e.com/"), *strong(tokens.text(".a")))).to eq(
          "[link|17]**.a**",
        )
      end

      it "puts the comment in front of a mention that text is glued to" do
        expect(write(tokens.text("hi"), placeholder("@alice", "[mention|3]"))).to eq(
          "hi<!---->[mention|3]",
        )
        expect(write(tokens.text("hi "), placeholder("@alice", "[mention|3]"))).to eq(
          "hi [mention|3]",
        )
      end

      it "escapes a ! in front of it only when like starts with [" do
        expect(write(tokens.text("Look!"), placeholder("[a](u)", "u1"))).to eq("Look\\!u1")
        expect(write(tokens.text("Look!"), placeholder)).to eq("Look![link|17]")
      end

      it "decides a bare URL in front of it by the start of like" do
        expect(write(tokens.bare_url("https://e.com/"), placeholder(" x"))).to eq(
          "https://e.com/[link|17]",
        )
        expect(write(tokens.bare_url("https://e.com/"), placeholder)).to eq(
          "[https://e.com/](https://e.com/)[link|17]",
        )
      end

      it "decides a bare URL after it by the end of like" do
        expect(write(placeholder("x "), tokens.bare_url("https://e.com/"))).to eq(
          "[link|17]https://e.com/",
        )
        expect(write(placeholder, tokens.bare_url("https://e.com/"))).to eq(
          "[link|17][https://e.com/](https://e.com/)",
        )
      end

      it "joins two placeholders by their like" do
        expect(write(placeholder, placeholder("@bob", "[mention|4]"))).to eq(
          "[link|17]<!---->[mention|4]",
        )
      end

      it "joins finished Markdown from a tag after it by the end of like" do
        expect(write(placeholder, tokens.raw("**.a**"))).to eq("[link|17]<!---->**.a**")
      end

      it "joins another buffer of the same length by its own end" do
        # The placeholder goes into the buffer of the emphasis, which is
        # as long as the text in front of the emphasis when the
        # emphasis is joined with it.
        expect(write(tokens.text("abcd."), *strong(placeholder("x", "[l|1]")))).to eq(
          "abcd.**[l|1]**",
        )
      end

      it "joins by the buffer again once something else was written after it" do
        expect(write(placeholder, tokens.text(" "), *strong(tokens.text(".a")))).to eq(
          "[link|17] **.a**",
        )
      end

      it "reads the placeholder itself at the inner edge of emphasis" do
        expect(write(tokens.text("x"), *strong(placeholder("@alice", "[mention|3]")))).to eq(
          "x<!---->**[mention|3]**",
        )
      end

      it "writes the placeholder text as it is in html_mode" do
        expect(write(*strong(tokens.text("a.")), placeholder, html_mode: true)).to eq(
          "<strong>a.</strong>[link|17]",
        )
      end
    end

    describe "links" do
      def link(destination, *content)
        [tokens.link_open(destination), *content, tokens.link_close]
      end

      it "writes the label and the destination" do
        expect(write(*link("https://e.com", tokens.text("a")))).to eq("[a](https://e.com)")
      end

      it "escapes the destination" do
        expect(write(*link("https://e.com/a(b)\\c d", tokens.text("a")))).to eq(
          "[a](<https://e.com/a\\(b\\)\\\\c d>)",
        )
      end

      it "keeps whitespace at the edges of the label outside the brackets" do
        expect(write(*link("/a", tokens.text(" a ")))).to eq(" [a](/a) ")
      end

      it "keeps a <br> at the edges of the label outside the brackets" do
        expect(
          write(
            tokens.text("a"),
            tokens.hard_break,
            *link("/a", tokens.hard_break, tokens.text("b")),
          ),
        ).to eq("a\n<br>[b](/a)")
        expect(write(*link("/a", tokens.text("b"), tokens.html("<br>")))).to eq("[b](/a)<br>")
      end

      it "writes a label with nothing visible without the link" do
        expect(write(*link("/a", tokens.text(" ")))).to eq(" ")
        expect(write(*link("/a"))).to eq("")
      end

      it "nests delimiters in the label" do
        expect(write(*link("/a", *em(tokens.text("a"))))).to eq("[*a*](/a)")
      end

      it "nests a link in a delimiter" do
        expect(write(*em(tokens.text("a"), *link("/a", tokens.text("b"))))).to eq("*a[b](/a)*")
      end

      it "pairs a link in a link by depth" do
        expect(write(*link("/a", *link("/b", tokens.text("x"))))).to eq("[[x](/b)](/a)")
      end

      it "escapes a ! in front of the link" do
        expect(write(tokens.text("a!"), *link("/a", tokens.text("b")))).to eq("a\\![b](/a)")
      end
    end

    describe "bare URLs" do
      let(:href) { "https://e.com/p" }
      let(:link) { "[#{href}](#{href})" }

      it "stays bare with whitespace on both sides" do
        expect(write(tokens.text("a "), tokens.bare_url(href), tokens.text(" b"))).to eq(
          "a #{href} b",
        )
      end

      it "stays bare on its own" do
        expect(write(tokens.bare_url(href))).to eq(href)
      end

      it "stays bare at the start and at the end of the run" do
        expect(write(tokens.bare_url(href), tokens.text(" b"))).to eq("#{href} b")
        expect(write(tokens.text("a "), tokens.bare_url(href))).to eq("a #{href}")
      end

      it "stays bare after a no-break space" do
        expect(write(tokens.text("a "), tokens.bare_url(href))).to eq("a #{href}")
      end

      it "stays bare after a <br>, which markdown-it reads as an HTML tag of its own" do
        expect(
          write(tokens.text("a"), tokens.hard_break, tokens.hard_break, tokens.bare_url(href)),
        ).to eq("a\n<br>#{href}")
      end

      it "becomes a link after another HTML tag" do
        expect(write(tokens.html("<sup>"), tokens.bare_url(href))).to eq("<sup>#{link}")
      end

      it "stays bare after an opening parenthesis and before a closing one" do
        expect(write(tokens.text("("), tokens.bare_url(href), tokens.text(")"))).to eq("(#{href})")
      end

      it "stays bare before sentence punctuation that whitespace or the end follows" do
        %w[. , ! ? ) .. ... !! ?? ). ),].each do |punctuation|
          expect(write(tokens.bare_url(href), tokens.text("#{punctuation} b"))).to eq(
            "#{href}#{punctuation} b",
          )
          expect(write(tokens.bare_url(href), tokens.text(punctuation))).to eq(
            "#{href}#{punctuation}",
          )
        end
      end

      it "becomes a link before punctuation that linkify keeps in the link" do
        %w[: .) ?! ., ,, ;].each do |punctuation|
          expect(write(tokens.bare_url(href), tokens.text("#{punctuation} b"))).to eq(
            "#{link}#{punctuation} b",
          )
        end
      end

      it "becomes a link before a closing parenthesis when the href has parentheses" do
        href = "https://e.com/a_(b)"

        link = "[https://e.com/a\\_(b)](https://e.com/a_\\(b\\))"

        expect(write(tokens.bare_url(href), tokens.text(") b"))).to eq("#{link}) b")
        expect(write(tokens.text("("), tokens.bare_url(href), tokens.text(")"))).to eq("(#{link})")
      end

      it "becomes a link with text glued to it" do
        expect(write(tokens.text("a"), tokens.bare_url(href))).to eq("a#{link}")
        expect(write(tokens.bare_url(href), tokens.text("b"))).to eq("#{link}b")
        expect(write(tokens.bare_url(href), tokens.text(".b"))).to eq("#{link}.b")
      end

      it "becomes a link after a multi-byte character" do
        expect(write(tokens.text("漢"), tokens.bare_url(href))).to eq("漢#{link}")
      end

      it "keeps the space of the text after it when the buffer ends in a blank line" do
        expect(write("a\n\n", tokens.bare_url(href), tokens.text(" y"))).to eq("a\n\n#{href} y")
      end

      it "becomes a link with text glued to it inside a wrapper" do
        expect(write(*em(tokens.text("see"), tokens.bare_url(href)))).to eq("*see#{link}*")
      end

      it "becomes a link next to a delimiter or a code span" do
        expect(write(*em(tokens.text("a")), tokens.bare_url(href))).to eq("*a*#{link}")
        expect(write(tokens.bare_url(href), tokens.code("x"))).to eq("#{link}`x`")
      end

      it "becomes a link in front of another bare URL" do
        expect(write(tokens.bare_url(href), tokens.bare_url(href))).to eq("#{link}#{link}")
      end

      it "escapes the label like a link label and the destination like a destination" do
        href = "https://e.com/a]b_c"

        expect(write(tokens.text("a"), tokens.bare_url(href))).to eq(
          "a[https://e.com/a\\]b\\_c](https://e.com/a]b_c)",
        )
      end

      it "becomes a link whatever the neighbors when linkify would not link the href" do
        expect(write(tokens.text("a "), tokens.bare_url("/t/5"), tokens.text(" b"))).to eq(
          "a [/t/5](/t/5) b",
        )
        expect(write(tokens.bare_url("#top"))).to eq("[#top](#top)")
        expect(write(tokens.bare_url("//example.com/x"))).to eq(
          "[//example.com/x](//example.com/x)",
        )
        expect(write(tokens.bare_url("mailto:a@example.com"))).to eq("mailto:a@example.com")
        expect(write(tokens.bare_url("ftp://example.com"))).to eq("ftp://example.com")
      end

      it "becomes a link for a query and a relative path, and stays text for a target that is neither" do
        expect(write(tokens.bare_url("?page=2"))).to eq("[?page=2](?page=2)")
        expect(write(tokens.bare_url("../up"))).to eq("[../up](../up)")
        expect(write(tokens.text("see"), tokens.bare_url("Page Name"), tokens.text("now"))).to eq(
          "seePage Namenow",
        )
      end

      it "stays bare after a hard break" do
        expect(write(tokens.text("a"), tokens.hard_break, tokens.bare_url(href))).to eq(
          "a\n#{href}",
        )
      end
    end

    describe "images" do
      it "writes the source and the alt text" do
        expect(write(tokens.image(src: "a.png", alt: "x"))).to eq("![x](a.png)")
      end

      it "writes no alt text when there is none" do
        expect(write(tokens.image(src: "a.png"))).to eq("![](a.png)")
      end

      it "escapes the alt text like a link label and the source like a destination" do
        expect(write(tokens.image(src: "a (b).png", alt: "x]*y*"))).to eq(
          "![x\\]\\*y\\*](<a \\(b\\).png>)",
        )
      end

      it "writes the size as Discourse reads it" do
        expect(write(tokens.image(src: "a.png", alt: "x", width: 10, height: 5))).to eq(
          "![x|10x5](a.png)",
        )
        expect(write(tokens.image(src: "a.png", height: 5, width: 10))).to eq("![|10x5](a.png)")
      end

      it "writes no size for a width or a height alone, Discourse takes only both" do
        expect(write(tokens.image(src: "a.png", alt: "x", width: 10))).to eq("![x](a.png)")
        expect(write(tokens.image(src: "a.png", alt: "x", height: 5))).to eq("![x](a.png)")
        expect(write(tokens.image(src: "a.png", width: 10))).to eq("![](a.png)")
      end

      it "keeps a part of the alt text that looks like an option apart from the options" do
        expect(write(tokens.image(src: "a.png", alt: "x|100x100", width: 10, height: 5))).to eq(
          "![x\\|100x100||10x5](a.png)",
        )
        expect(write(tokens.image(src: "a.png", alt: "x|thumbnail"))).to eq(
          "![x\\|thumbnail|](a.png)",
        )
        expect(write(tokens.image(src: "a.png", alt: "x|k=v"))).to eq("![x\\|k=v|](a.png)")
        expect(write(tokens.image(src: "a.png", alt: "x|y"))).to eq("![x\\|y](a.png)")
      end

      it "puts the alt text on one line" do
        expect(write(tokens.image(src: "a.png", alt: "x \n\n y \nz"))).to eq("![x y z](a.png)")
      end
    end

    describe "errors" do
      it "refuses a close token without its open token" do
        expect { write(tokens.close(:em)) }.to raise_error(
          ArgumentError,
          "close token without an open token in front of it",
        )
        expect { write(tokens.link_close) }.to raise_error(
          ArgumentError,
          "link_close token without an open token in front of it",
        )
      end

      it "refuses an open token without its close token" do
        message = "open token without a close token after it"

        expect { write(tokens.open(:em), tokens.text("a")) }.to raise_error(ArgumentError, message)
        expect { write(*em(tokens.open(:em))) }.to raise_error(ArgumentError, message)
        expect { write(tokens.link_open("/a")) }.to raise_error(
          ArgumentError,
          "link_open token without a link_close token after it",
        )
      end

      it "does not close a delimiter with the close token of another" do
        expect { write(tokens.open(:em), tokens.close(:strong)) }.to raise_error(
          ArgumentError,
          "open token without a close token after it",
        )
      end

      it "refuses an unknown token" do
        expect { write([:bold, "a"]) }.to raise_error(
          ArgumentError,
          'unknown inline token [:bold, "a"]',
        )
      end

      it "writes a String among the tokens as it is" do
        expect(write("**a**", tokens.text("*"), "")).to eq("**a**\\*")
      end
    end

    # One character class at the inner edge of a text and an emphasis,
    # and around a bare URL. The classes are the ones the adjacency
    # round-trip builds its cases from, so a rule that changes shows
    # here first.
    describe "character classes at the edges" do
      EDGE_OUTPUTS = {
        "a" => ["xa*ay*", "*xa*ay", "xa[https://e.com/p](https://e.com/p)ay"],
        "1" => ["x1*1y*", "*x1*1y", "x1[https://e.com/p](https://e.com/p)1y"],
        "space" => ["x  *y*", "*x*  y", "x https://e.com/p y"],
        "*" => [
          "x\\*<em>\\*y</em>",
          "<em>x\\*</em>\\*y",
          "x\\*[https://e.com/p](https://e.com/p)\\*y",
        ],
        "_" => ["x\\_*\\_y*", "*x\\_*\\_y", "x\\_[https://e.com/p](https://e.com/p)\\_y"],
        "~" => ["x~<!---->*~y*", "*x~*<!---->~y", "x~[https://e.com/p](https://e.com/p)~y"],
        "`" => ["x\\`*\\`y*", "*x\\`*\\`y", "x\\`[https://e.com/p](https://e.com/p)\\`y"],
        "!" => ["x!*!y*", "*x!*!y", "x\\![https://e.com/p](https://e.com/p)!y"],
        "[" => ["x\\[*\\[y*", "*x\\[*\\[y", "x\\[[https://e.com/p](https://e.com/p)\\[y"],
        "]" => ["x]*]y*", "*x]*]y", "x][https://e.com/p](https://e.com/p)]y"],
        "(" => ["x(*(y*", "*x(*(y", "x([https://e.com/p](https://e.com/p)(y"],
        ")" => ["x)*)y*", "*x)*)y", "x)[https://e.com/p](https://e.com/p))y"],
        "<" => ["x<*\\<y*", "*x<*\\<y", "x<[https://e.com/p](https://e.com/p)\\<y"],
        ">" => ["x>*\\>y*", "*x>*\\>y", "x>[https://e.com/p](https://e.com/p)\\>y"],
        "&" => ["x&*&y*", "*x&*&y", "x&[https://e.com/p](https://e.com/p)&y"],
        "\\" => ["x\\\\*\\y*", "*x\\\\*\\y", "x\\\\[https://e.com/p](https://e.com/p)\\y"],
        "#" => ["x#*#y*", "*x#*#y", "x#[https://e.com/p](https://e.com/p)#y"],
        "|" => ["x\\|*\\|y*", "*x\\|*\\|y", "x\\|[https://e.com/p](https://e.com/p)\\|y"],
        "." => ["x.*.y*", "*x.*.y", "x.[https://e.com/p](https://e.com/p).y"],
        "-" => ["x-*-y*", "*x-*-y", "x-[https://e.com/p](https://e.com/p)-y"],
        ":" => ["x:*:y*", "*x:*:y", "x:[https://e.com/p](https://e.com/p):y"],
        "dot-space" => ["x. *. y*", "*x.* . y", "x. https://e.com/p. y"],
        "nbsp" => %w[x  *y* *x*  y x https://e.com/p y],
        "“" => ["x“<!---->*“y*", "*x“*<!---->“y", "x“[https://e.com/p](https://e.com/p)“y"],
        "「" => ["x「<!---->*「y*", "*x「*<!---->「y", "x「[https://e.com/p](https://e.com/p)「y"],
        "€" => ["x€<!---->*€y*", "*x€*<!---->€y", "x€[https://e.com/p](https://e.com/p)€y"],
        "漢" => ["x漢*漢y*", "*x漢*漢y", "x漢[https://e.com/p](https://e.com/p)漢y"],
        "😀" => ["x😀<!---->*😀y*", "*x😀*<!---->😀y", "x😀[https://e.com/p](https://e.com/p)😀y"],
      }.freeze

      AdjacencyGenerator::EDGES.each do |name, char|
        text_then_em, em_then_text, around_url = EDGE_OUTPUTS.fetch(name)

        it "writes text ending in #{name} in front of emphasis starting with it" do
          expect(write(tokens.text("x#{char}"), *em(tokens.text("#{char}y")))).to eq(text_then_em)
        end

        it "writes emphasis ending in #{name} in front of text starting with it" do
          expect(write(*em(tokens.text("x#{char}")), tokens.text("#{char}y"))).to eq(em_then_text)
        end

        it "writes a bare URL between #{name} on both sides" do
          url = tokens.bare_url("https://e.com/p")

          expect(write(tokens.text("x#{char}"), url, tokens.text("#{char}y"))).to eq(around_url)
        end
      end
    end
  end

  describe "#write with html_mode" do
    def html(*tokens)
      write(*tokens, html_mode: true)
    end

    it "escapes text for HTML whatever its mode" do
      expect(
        html(
          tokens.text("<a>"),
          tokens.text("<b>", tokens::LABEL),
          tokens.text("<c>", tokens::VERBATIM),
        ),
      ).to eq("&lt;a&gt;&lt;b&gt;&lt;c&gt;")
    end

    it "writes raw Markdown and HTML as they are" do
      expect(html(tokens.raw("\n\n**a**\n\n"), tokens.html("<sup>2</sup>"))).to eq(
        "\n\n**a**\n\n<sup>2</sup>",
      )
    end

    it "writes the newline in front of a blank line in text as an entity" do
      # A blank line would end the HTML block.
      expect(html(tokens.text("a\n\nb"))).to eq("a&#10;\nb")
    end

    it "writes the HTML tags of a delimiter, not around nothing visible" do
      expect(html(tokens.open(:strong), tokens.text("a"), tokens.close(:strong))).to eq(
        "<strong>a</strong>",
      )
      expect(html(*em(tokens.text("a")))).to eq("<em>a</em>")
      expect(html(tokens.open(:s), tokens.text("a"), tokens.close(:s))).to eq("<s>a</s>")
      expect(html(tokens.open(:u), tokens.text("a"), tokens.close(:u))).to eq(
        %(<span class="bbcode-u">a</span>),
      )
      expect(html(*em(tokens.text(" ")))).to eq(" ")
      expect(html(*em)).to eq("")
    end

    it "writes a code span as a code element" do
      expect(html(tokens.code("a<b"))).to eq("<code>a&lt;b</code>")
      expect(html(tokens.code(""))).to eq("")
    end

    it "writes a link as an anchor" do
      expect(html(tokens.link_open("/a?b&c"), tokens.text("x"), tokens.link_close)).to eq(
        %(<a href="/a?b&amp;c">x</a>),
      )
    end

    it "writes nested pairs as HTML throughout" do
      strong = tokens.open(:strong), *em(tokens.text("a")), tokens.close(:strong)
      link = tokens.link_open("/a"), *em(tokens.text("b")), tokens.link_close

      expect(html(*strong, *link)).to eq(%(<strong><em>a</em></strong><a href="/a"><em>b</em></a>))
    end

    it "writes a bare URL as an anchor" do
      expect(html(tokens.bare_url("https://e.com/?a&b"))).to eq(
        %(<a href="https://e.com/?a&amp;b">https://e.com/?a&amp;b</a>),
      )
    end

    it "writes an image as an img element" do
      expect(html(tokens.image(src: "a&b.png", alt: "<x>", width: 10, height: 5))).to eq(
        %(<img src="a&amp;b.png" alt="&lt;x&gt;" width="10" height="5">),
      )
      expect(html(tokens.image(src: "a.png"))).to eq(%(<img src="a.png" alt="">))
      expect(html(tokens.image(src: "a.png", width: 10))).to eq(
        %(<img src="a.png" alt="" width="10">),
      )
    end

    it "writes a hard break as a br element" do
      expect(html(tokens.hard_break)).to eq("<br>")
    end

    it "joins nothing inside a pair either" do
      expect(
        html(tokens.open(:strong), tokens.raw("`a`"), tokens.raw("`b`"), tokens.close(:strong)),
      ).to eq("<strong>`a``b`</strong>")
    end

    it "joins nothing: a ! in front of a link stays a !" do
      expect(
        html(tokens.text("a!"), tokens.link_open("/a"), tokens.text("b"), tokens.link_close),
      ).to eq(%(a!<a href="/a">b</a>))
      expect(html(tokens.raw("`a`"), tokens.raw("`b`"))).to eq("`a``b`")
    end
  end

  describe "#write_groups" do
    def write_groups(groups, html_mode: false, &before)
      outputs = groups.to_h
      serializer.write_groups(groups.map(&:first), html_mode:, before:) do |child|
        outputs.fetch(child)
      end
    end

    it "joins finished Markdown of the next group by the end of a placeholder's like" do
      placeholder = tokens.placeholder("[link|17]", like: "https://e.com/t/17")

      expect(write_groups([[:a, [placeholder]], [:b, "**.a**"]])).to eq("[link|17]<!---->**.a**")
      expect(write_groups([[:a, [placeholder]], [:b, " **.a**"]])).to eq("[link|17] **.a**")
    end

    it "fits an output to the line it starts, from the state of the buffer" do
      expect(write_groups([[:a, "a\n\n"], [:b, "   b"]])).to eq("a\n\nb")
      expect(write_groups([[:a, "a\n"], [:b, "   b"]])).to eq("a\n   b")
      expect(write_groups([[:a, "\n"], [:b, "   b"]])).to eq("\n   b")
      expect(write_groups([[:a, "\n\n"], [:b, "   b"]])).to eq("\n\nb")
      expect(write_groups([[:a, "a\n\n"], [:b, "   b"]], html_mode: true)).to eq("a\n\n   b")
      expect(
        write_groups([[:a, "a\n\n"], [:b, [tokens.bare_url("https://e.com/")]], [:c, "   b"]]),
      ).to eq("a\n\nhttps://e.com/   b")
    end

    it "goes on after an output that is empty, without a word to the hook" do
      seen = []

      expect(write_groups([[:a, "a"], [:b, ""], [:c, "c"]]) { |_, child| seen << child }).to eq(
        "ac",
      )
      expect(seen).to eq(%i[a c])
      expect(write_groups([[:a, "a"], [:b, []], [:c, "c"]])).to eq("ac")
      expect(write_groups([[:a, "a\n\n"], [:b, "   "], [:c, "c"]])).to eq("a\n\nc")
    end

    it "lets a waiting bare URL wait through an empty output" do
      groups = [[:a, [tokens.bare_url("https://e.com/")]], [:b, ""], [:c, "now"]]

      expect(write_groups(groups)).to eq("[https://e.com/](https://e.com/)now")
    end

    it "takes a <br> at the end of the group off again, not in html_mode" do
      groups = [[:a, "a\n"], [:b, [tokens.hard_break]], [:c, [tokens.hard_break]]]

      expect(write_groups(groups)).to eq("a\n")
      expect(write_groups(groups, html_mode: true)).to eq("a\n<br><br>")
    end

    it "writes finished Markdown and tokens one after the other" do
      groups = [[:a, "a*"], [:b, em(tokens.text("b"))], [:c, [tokens.text("c")]]]

      expect(write_groups(groups)).to eq("a*<!---->*b*c")
    end

    it "joins across the groups" do
      expect(write_groups([[:a, "**a**"], [:b, [tokens.raw("**b**")]]])).to eq("**a**<!---->**b**")
      expect(write_groups([[:a, "**a**"], [:b, "**b**"]])).to eq("**a**<!---->**b**")
    end

    it "writes Markdown when html_mode is not given, and needs no before" do
      outputs = { a: "`a`", b: "`b`" }

      expect(serializer.write_groups(%i[a b]) { |child| outputs.fetch(child) }).to eq(
        "`a`<!---->`b`",
      )
    end

    it "yields the buffer and the child in front of the child's first piece" do
      seen = []
      groups = [[:a, "a"], [:b, [tokens.text("b"), tokens.text("c")]]]

      result = write_groups(groups) { |buffer, child| seen << [buffer.dup, child] }

      expect(result).to eq("abc")
      expect(seen).to eq([["", :a], ["a", :b]])
    end

    it "keeps what the block wrote to the buffer" do
      groups = [[:a, "a"], [:b, "b"], [:c, [tokens.text("c")]]]

      expect(write_groups(groups) { |buffer, child| buffer << "|" if child != :a }).to eq("a|b|c")
    end

    it "does not yield for a child without output" do
      seen = []
      groups = [[:a, ""], [:b, []], [:c, [tokens.code("")]], [:d, "d"]]

      write_groups(groups) { |_, child| seen << child }

      expect(seen).to eq([:d])
    end

    it "decides a bare URL at the end of a group by the next group" do
      href = "https://e.com/p"

      expect(write_groups([[:a, [tokens.bare_url(href)]], [:b, "b"]])).to eq("[#{href}](#{href})b")
      expect(write_groups([[:a, [tokens.bare_url(href)]], [:b, [tokens.text("b")]]])).to eq(
        "[#{href}](#{href})b",
      )
      expect(write_groups([[:a, [tokens.bare_url(href)]], [:b, [tokens.text(" b")]]])).to eq(
        "#{href} b",
      )
      expect(write_groups([[:a, [tokens.text("a "), tokens.bare_url(href)]], [:b, "b"]])).to eq(
        "a [#{href}](#{href})b",
      )
      expect(write_groups([[:a, [tokens.bare_url(href)]], [:b, [tokens.bare_url(href)]]])).to eq(
        "[#{href}](#{href})[#{href}](#{href})",
      )
    end

    it "takes the next group for the look-ahead, wherever the group is" do
      href = "https://e.com/p"
      groups = [[:a, " a "], [:x, "x "], [:b, [tokens.bare_url(href)]], [:c, " c"]]

      expect(write_groups(groups)).to eq(" a x #{href} c")
    end

    it "keeps a bare URL bare when the next group has no output, or there is none" do
      href = "https://e.com/p"

      expect(write_groups([[:a, [tokens.bare_url(href)]], [:b, ""]])).to eq(href)
      expect(write_groups([[:a, [tokens.bare_url(href)]], [:b, []]])).to eq(href)
      expect(write_groups([[:a, [tokens.bare_url(href)]]])).to eq(href)
    end

    it "writes HTML in html_mode and joins nothing" do
      groups = [
        [:a, "<b>a</b>"],
        [:b, em(tokens.text("b"))],
        [:c, "`a`"],
        [:d, "`b`"],
        [:e, [tokens.raw("`c`")]],
      ]

      expect(write_groups(groups, html_mode: true)).to eq("<b>a</b><em>b</em>`a``b``c`")
    end

    it "yields before the pieces of a child, after the bare URL of the child in front" do
      href = "https://e.com/p"
      seen = []
      groups = [[:a, [tokens.bare_url(href)]], [:b, "b"]]

      write_groups(groups) { |buffer, child| seen << [buffer.dup, child] }

      expect(seen).to eq([["", :a], ["[#{href}](#{href})", :b]])
    end
  end
end
