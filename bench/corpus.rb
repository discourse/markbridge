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

  def build(words, count: 200, seed: 42)
    rng = Random.new(seed)
    Array.new(count) { post(rng, words) }
  end

  def ascii
    @ascii ||= build(WORDS_ASCII)
  end

  def multibyte
    @multibyte ||= build(WORDS_MULTI)
  end
end
