# frozen_string_literal: true

# Deterministic synthetic corpus of forum-post-shaped BBCode documents
# for bench/corpus_bench.rb and bench/alloc_profile.rb.
#
# Two variants with the same structure: ASCII prose and multibyte prose.
# The multibyte variant exists because character-index string operations
# in CRuby degrade superlinearly on multibyte input — a corpus without it
# hides that entire failure mode.
module Corpus
  WORDS_ASCII = %w[
    the
    quick
    brown
    fox
    jumps
    over
    lazy
    dog
    while
    some
    other
    words
    fill
    sentences
    about
    servers
    databases
    migration
    threads
    posts
    users
    forum
    upgrade
    version
    plugin
    theme
    category
    topic
    reply
    moderator
    admin
  ].freeze

  WORDS_MULTI = %w[
    das
    schöne
    Mädchen
    läuft
    über
    die
    Straße
    größer
    kleiner
    Übung
    café
    naïve
    résumé
    Zürich
    München
    Österreich
    straße
    äöü
    éàè
    日本語
    テスト
    漢字
    こんにちは
    世界
    привет
    мир
    тест
  ].freeze

  module_function

  def sentence(rng, words, count)
    Array.new(count) { words[rng.rand(words.size)] }.join(" ")
  end

  def paragraph(rng, words)
    "#{Array.new(2 + rng.rand(3)) { sentence(rng, words, 8 + rng.rand(10)) }.join(". ")}."
  end

  # A post: several paragraphs, sprinkled with BBCode constructs.
  def post(rng, words)
    parts = []
    parts << paragraph(rng, words)
    parts << "[b]#{sentence(rng, words, 4)}[/b] and [i]#{sentence(rng, words, 3)}[/i]"
    parts << glued_emphasis(rng, words)
    parts << paragraph(rng, words)
    parts << construct(rng, words)
    parts << paragraph(rng, words)
    parts.join("\n\n")
  end

  # Emphasis with no space between the delimiter and the word next to
  # it, and content that ends in punctuation. CommonMark's flanking
  # rules make the renderer look at the bytes around such a run before
  # it can decide whether the Markdown form works at all, and the
  # spaced form above never reaches that code.
  def glued_emphasis(rng, words)
    "#{sentence(rng, words, 1)}[b]#{sentence(rng, words, 3)}![/b]and" \
      "[i]#{sentence(rng, words, 2)}?[/i]#{sentence(rng, words, 1)}"
  end

  def construct(rng, words)
    case rng.rand(6)
    when 0
      "[quote=\"alice\"]\n#{paragraph(rng, words)}\n[/quote]"
    when 1
      items = Array.new(3 + rng.rand(3)) { "[*]#{sentence(rng, words, 5)}" }
      "[list]\n#{items.join("\n")}\n[/list]"
    when 2
      "[code]\ndef hello\n  puts 'x = 1'\nend\n[/code]"
    when 3
      "See [url=https://example.com/#{rng.rand(1000)}]#{sentence(rng, words, 3)}[/url] for details."
    when 4
      "[table]\n[tr][th]A[/th][th]B[/th][/tr]\n" \
        "[tr][td]#{words[rng.rand(words.size)]}[/td][td]2[/td][/tr]\n[/table]"
    when 5
      "Text with *asterisks*, _underscores_ and -- dashes. #{paragraph(rng, words)}"
    end
  end

  # A MediaWiki post: same shape as the BBCode one, wikitext syntax.
  # Prose includes apostrophes (possessives) on purpose — apostrophe
  # handling is the inline parser's hottest dispatch.
  def mediawiki_post(rng, words)
    parts = []
    parts << "== #{sentence(rng, words, 3)} =="
    parts << "#{paragraph(rng, words)} It's #{words[rng.rand(words.size)]}'s turn."
    parts << "'''#{sentence(rng, words, 4)}''' and ''#{sentence(rng, words, 3)}''"
    parts << "#{sentence(rng, words, 1)}'''#{sentence(rng, words, 3)}!'''and" \
      "''#{sentence(rng, words, 2)}?''#{sentence(rng, words, 1)}"
    parts << paragraph(rng, words)
    parts << mediawiki_construct(rng, words)
    parts << paragraph(rng, words)
    parts.join("\n\n")
  end

  def mediawiki_construct(rng, words)
    case rng.rand(6)
    when 0
      "[[#{sentence(rng, words, 2)}|#{sentence(rng, words, 3)}]] inside a sentence."
    when 1
      Array.new(3 + rng.rand(3)) { "* #{sentence(rng, words, 5)}" }.join("\n")
    when 2
      "<code>x = #{rng.rand(100)}</code> and <pre>keep   this</pre>"
    when 3
      "See [https://example.com/#{rng.rand(1000)} #{sentence(rng, words, 3)}] for details."
    when 4
      "{|\n|-\n! A !! B\n|-\n| #{words[rng.rand(words.size)]} || 2\n|}"
    when 5
      "''''' #{sentence(rng, words, 4)} ''''' with <s>#{sentence(rng, words, 2)}</s>"
    end
  end

  # An HTML post with the same overall shape.
  def html_post(rng, words)
    parts = []
    parts << "<p>#{paragraph(rng, words)}</p>"
    parts << "<p><strong>#{sentence(rng, words, 4)}</strong> and <em>#{sentence(rng, words, 3)}</em></p>"
    parts << "<p>#{sentence(rng, words, 1)}<strong>#{sentence(rng, words, 3)}!</strong>and" \
      "<em>#{sentence(rng, words, 2)}?</em>#{sentence(rng, words, 1)}</p>"
    parts << "<p>#{paragraph(rng, words)}</p>"
    parts << html_construct(rng, words)
    parts << "<p>#{paragraph(rng, words)}</p>"
    parts.join("\n")
  end

  def html_construct(rng, words)
    case rng.rand(5)
    when 0
      "<blockquote><p>#{paragraph(rng, words)}</p></blockquote>"
    when 1
      "<ul>#{Array.new(3 + rng.rand(3)) { "<li>#{sentence(rng, words, 5)}</li>" }.join}</ul>"
    when 2
      "<pre><code>def hello\n  puts 'x'\nend</code></pre>"
    when 3
      "<p>See <a href=\"https://example.com/#{rng.rand(1000)}\">#{sentence(rng, words, 3)}</a>.</p>"
    when 4
      "<table><tr><th>A</th><th>B</th></tr><tr><td>#{words[rng.rand(words.size)]}</td><td>2</td></tr></table>"
    end
  end

  # An s9e/TextFormatter XML post (the phpBB 3.2+ storage format), shaped
  # like real phpBB 3.x posts. A line break is `<br/>` followed by a
  # newline in the next text node, a paragraph break is two of them. Most
  # posts are short, with a few line breaks, and a quote of the post they
  # reply to in about every fourth post. A post without markup has the
  # plain-text root <t>.
  def text_formatter_post(rng, words)
    rich = false
    paragraphs =
      Array.new(text_formatter_paragraph_count(rng)) do
        lines =
          Array.new(1 + rng.rand(2)) do
            line = text_formatter_line(rng, words)
            rich ||= line.include?("<")
            line
          end
        lines.join("<br/>\n")
      end
    body = paragraphs.join("<br/>\n<br/>\n")
    quote = rng.rand < TF_QUOTE_SHARE
    body = "#{text_formatter_quote(rng, words)}#{body}" if quote
    rich || quote ? "<r>#{body}</r>" : "<t>#{body}</t>"
  end

  # Many posts are one paragraph, some are long announcements.
  def text_formatter_paragraph_count(rng)
    roll = rng.rand
    if roll < 0.45
      1
    elsif roll < 0.85
      2 + rng.rand(2)
    else
      4 + rng.rand(8)
    end
  end

  # Share of posts with a quote.
  TF_QUOTE_SHARE = 0.28

  # Chance per line for each inline construct. A post has three lines on
  # average, so these are about a third of the share of posts that use
  # the construct.
  TF_LINE_CONSTRUCTS = [
    [0.020, :tf_url],
    [0.023, :tf_bare_url],
    [0.016, :tf_smiley],
    [0.007, :tf_bold],
    [0.007, :tf_glued_bold],
    [0.010, :tf_italic],
    [0.008, :tf_image],
    [0.005, :tf_underline],
    [0.005, :tf_color],
    [0.003, :tf_email],
    [0.003, :tf_size],
    [0.001, :tf_attachment],
    [0.001, :tf_list],
    [0.0001, :tf_code],
  ].freeze

  def text_formatter_line(rng, words)
    line = sentence(rng, words, 10 + rng.rand(14))
    TF_LINE_CONSTRUCTS.each do |chance, construct|
      next if rng.rand >= chance

      line =
        "#{line} #{public_send(construct, rng, words)} #{sentence(rng, words, 2 + rng.rand(4))}"
    end
    line
  end

  def text_formatter_quote(rng, words)
    lines = Array.new(1 + rng.rand(2)) { sentence(rng, words, 8 + rng.rand(10)) }
    "<QUOTE author=\"alice\"><s>[quote=\"alice\"]</s>#{lines.join("<br/>\n")}<e>[/quote]</e></QUOTE>"
  end

  def tf_url(rng, words)
    url = "https://example.com/#{rng.rand(1000)}"
    "<URL url=\"#{url}\"><s>[url=#{url}]</s>#{sentence(rng, words, 3)}<e>[/url]</e></URL>"
  end

  def tf_bare_url(rng, _words)
    url = "https://example.com/viewtopic.php?f=#{rng.rand(50)}&amp;t=#{rng.rand(100_000)}"
    "<URL url=\"#{url}\"><LINK_TEXT text=\"https://example.com/viewtopic.php ... \">#{url}</LINK_TEXT></URL>"
  end

  def tf_smiley(_rng, _words)
    "<E>:)</E>"
  end

  def tf_bold(rng, words)
    "<B><s>[b]</s>#{sentence(rng, words, 3)}<e>[/b]</e></B>"
  end

  # Bold with no space between the delimiter and the word next to it,
  # and content that ends in punctuation. CommonMark's flanking rules
  # make the renderer look at the bytes around such a run.
  def tf_glued_bold(rng, words)
    "#{sentence(rng, words, 1)}<B><s>[b]</s>#{sentence(rng, words, 2)}!<e>[/b]</e></B>and"
  end

  def tf_italic(rng, words)
    "<I><s>[i]</s>#{sentence(rng, words, 3)}<e>[/i]</e></I>"
  end

  def tf_image(rng, _words)
    src = "https://example.com/images/#{rng.rand(1000)}.png"
    "<IMG src=\"#{src}\"><s>[img]</s>#{src}<e>[/img]</e></IMG>"
  end

  def tf_underline(rng, words)
    "<U><s>[u]</s>#{sentence(rng, words, 2)}<e>[/u]</e></U>"
  end

  def tf_color(rng, words)
    "<COLOR color=\"#FF0000\"><s>[color=#FF0000]</s>#{sentence(rng, words, 3)}<e>[/color]</e></COLOR>"
  end

  def tf_email(rng, _words)
    address = "user#{rng.rand(100)}@example.com"
    "<EMAIL email=\"#{address}\">#{address}</EMAIL>"
  end

  def tf_size(rng, words)
    "<SIZE size=\"150\"><s>[size=150]</s>#{sentence(rng, words, 3)}<e>[/size]</e></SIZE>"
  end

  def tf_attachment(rng, _words)
    name = "photo#{rng.rand(100)}.jpg"
    "<ATTACHMENT filename=\"#{name}\" index=\"0\"><s>[attachment=0]</s>#{name}<e>[/attachment]</e></ATTACHMENT>"
  end

  def tf_list(rng, words)
    items = Array.new(3 + rng.rand(4)) { "<LI><s>[*]</s>#{sentence(rng, words, 5)}</LI>" }
    "<LIST><s>[list]</s><i>\n</i>#{items.join("\n")}<e>[/list]</e></LIST>"
  end

  def tf_code(rng, _words)
    "<CODE><s>[code]</s>x = #{rng.rand(100)}\nputs x<e>[/code]</e></CODE>"
  end

  def build(words, count: 200, seed: 42, kind: :post)
    rng = Random.new(seed)
    Array.new(count) { public_send(kind, rng, words) }
  end

  def ascii
    @ascii ||= build(WORDS_ASCII)
  end

  def multibyte
    @multibyte ||= build(WORDS_MULTI)
  end

  def mediawiki
    @mediawiki ||= build(WORDS_ASCII, kind: :mediawiki_post)
  end

  def mediawiki_multibyte
    @mediawiki_multibyte ||= build(WORDS_MULTI, kind: :mediawiki_post)
  end

  def html
    @html ||= build(WORDS_ASCII, kind: :html_post)
  end

  def html_multibyte
    @html_multibyte ||= build(WORDS_MULTI, kind: :html_post)
  end

  def text_formatter
    @text_formatter ||= build(WORDS_ASCII, kind: :text_formatter_post)
  end

  def text_formatter_multibyte
    @text_formatter_multibyte ||= build(WORDS_MULTI, kind: :text_formatter_post)
  end
end
