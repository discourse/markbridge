# frozen_string_literal: true

require "open3"

module DocsCodeExamples
  REPO_ROOT = SPEC_ROOT.parent.expand_path
  DOCS_DIR = REPO_ROOT.join("docs", "src", "content", "docs")
  LIB_DIR = REPO_ROOT.join("lib").to_s

  HTML_COMMENT = /<!--(.+?)-->/m
  MDX_COMMENT = %r{\{/\*(.+?)\*/\}}m

  module_function

  # Returns [{ line:, code:, setup:, continue: }] per fenced ```ruby block.
  #
  # Two directives, each delivered via an HTML or MDX comment that precedes the
  # block (with optional blank lines in between):
  #
  #   <!-- spec:continue -->     prepend every preceding ```ruby block in this
  #                              file. Use for narrative docs that build up an
  #                              example across several snippets.
  #
  #   <!-- spec:before
  #     ruby_code = "here"       provide invisible setup for the next block.
  #   -->                        Use for placeholders the reader sees (e.g.
  #                              `...`) but the spec needs filled in.
  #
  # Multiple `spec:before` comments accumulate; they all flush at the next
  # ```ruby block. There is intentionally no skip directive — every Ruby block
  # in the docs must run.
  def extract_blocks(content)
    blocks = []
    setup = []
    continue_next = false
    lines = content.lines
    i = 0

    while i < lines.length
      line = lines[i]

      if line.lstrip.start_with?("<!--") || line.lstrip.start_with?("{/*")
        comment, consumed = read_comment(lines, i)
        case classify(comment)
        in :continue
          continue_next = true
        in [:before, body]
          setup << body unless body.empty?
        else
          # unrelated HTML/MDX comment — ignore
        end
        i += consumed
        next
      end

      if line.match?(/\A```ruby\s*\z/)
        first_line_no = i + 2
        buffer = []
        i += 1
        while i < lines.length && !lines[i].match?(/\A```\s*\z/)
          buffer << lines[i]
          i += 1
        end
        blocks << {
          line: first_line_no,
          code: buffer.join,
          setup: setup.dup,
          continue: continue_next,
        }
        setup = []
        continue_next = false
      end

      i += 1
    end
    blocks
  end

  # Returns [comment_body, lines_consumed]. `lines_consumed` is always >= 1
  # so callers can advance their cursor past the comment, even when the
  # whole comment is on a single line.
  def read_comment(lines, start_index)
    chunk = []
    j = start_index
    while j < lines.length
      chunk << lines[j]
      break if chunk.last.include?("-->") || chunk.last.include?("*/}")

      j += 1
    end
    text = chunk.join
    body = text[HTML_COMMENT, 1] || text[MDX_COMMENT, 1] || ""
    [body, chunk.length]
  end

  def classify(comment_body)
    stripped = comment_body.strip
    return :continue if stripped == "spec:continue"
    return :before, stripped.sub(/\Aspec:before\b\s*/, "") if stripped.start_with?("spec:before")

    nil
  end

  def wrap(code)
    if code.match?(/^\s*require\s+["']markbridge/)
      "include Markbridge\n#{code}"
    else
      %(require "markbridge/all"\ninclude Markbridge\n#{code})
    end
  end

  def run(source)
    # `-rbundler/setup` lets snippets `require` gems listed in the project's
    # Gemfile (e.g., csv, benchmark) without bin/setup leaking into Ruby's
    # default load path.
    Open3.capture3(
      { "RUBYOPT" => "-W0 -rbundler/setup" },
      "ruby",
      "-I",
      LIB_DIR,
      stdin_data: source,
    )
  end

  def failure_message(stdout, stderr, status, source)
    <<~MSG
      Ruby exited #{status.exitstatus}.

      --- stderr ---
      #{stderr}
      --- stdout ---
      #{stdout}
      --- source (with injected setup) ---
      #{source}
    MSG
  end

  def assemble(block, preceding)
    own_full = (block[:setup] + [block[:code]]).join("\n")
    if block[:continue]
      (preceding + [own_full]).join("\n")
    else
      own_full
    end
  end
end

RSpec.describe "Docs code examples" do
  Dir[DocsCodeExamples::DOCS_DIR.join("**", "*.{md,mdx}").to_s].sort.each do |path|
    rel = Pathname.new(path).relative_path_from(DocsCodeExamples::REPO_ROOT).to_s
    blocks = DocsCodeExamples.extract_blocks(File.read(path))
    next if blocks.empty?

    describe rel do
      preceding = []

      blocks.each_with_index do |block, idx|
        title = "block #{idx + 1} (around #{rel}:#{block[:line]})"
        source = DocsCodeExamples.assemble(block, preceding)
        preceding << (block[:setup] + [block[:code]]).join("\n")
        wrapped = DocsCodeExamples.wrap(source)

        it title do
          stdout, stderr, status = DocsCodeExamples.run(wrapped)
          expect(status).to be_success,
          -> { DocsCodeExamples.failure_message(stdout, stderr, status, wrapped) }
        end
      end
    end
  end
end
