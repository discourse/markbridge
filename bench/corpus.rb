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
    parts << paragraph(rng, words)
    parts << construct(rng, words)
    parts << paragraph(rng, words)
    parts.join("\n\n")
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
end
