# frozen_string_literal: true

require "open3"

module DocsCodeExamples
  REPO_ROOT = SPEC_ROOT.parent.expand_path
  DOCS_DIR = REPO_ROOT.join("docs", "src", "content", "docs")
  LIB_DIR = REPO_ROOT.join("lib").to_s

  module_function

  # Returns an array of { line:, code: } for every fenced ```ruby block.
  def extract_blocks(content)
    blocks = []
    lines = content.lines
    i = 0
    while i < lines.length
      if lines[i].match?(/\A```ruby\s*\z/)
        # 1-based line number of the first line of code (after the fence).
        first_line_no = i + 2
        buffer = []
        i += 1
        while i < lines.length && !lines[i].match?(/\A```\s*\z/)
          buffer << lines[i]
          i += 1
        end
        blocks << { line: first_line_no, code: buffer.join }
      end
      i += 1
    end
    blocks
  end

  # Prepend setup so the example runs standalone:
  #   - If it already has `require "markbridge/..."`, leave the require alone.
  #   - Otherwise pull in everything via `markbridge/all`.
  #   - Always `include Markbridge` so short-form references like `AST::Foo`,
  #     `Renderers::Discourse::Renderer`, etc. resolve without the `Markbridge::`
  #     prefix the docs typically omit for readability.
  def wrap(code)
    if code.match?(/^\s*require\s+["']markbridge/)
      "include Markbridge\n#{code}"
    else
      %(require "markbridge/all"\ninclude Markbridge\n#{code})
    end
  end

  def run(source)
    Open3.capture3({ "RUBYOPT" => "-W0" }, "ruby", "-I", LIB_DIR, stdin_data: source)
  end
end

RSpec.describe "Docs code examples" do
  Dir[DocsCodeExamples::DOCS_DIR.join("**", "*.{md,mdx}").to_s].sort.each do |path|
    rel = Pathname.new(path).relative_path_from(DocsCodeExamples::REPO_ROOT).to_s
    blocks = DocsCodeExamples.extract_blocks(File.read(path))
    next if blocks.empty?

    describe rel do
      blocks.each_with_index do |block, idx|
        it "block #{idx + 1} (around #{rel}:#{block[:line]})" do
          source = DocsCodeExamples.wrap(block[:code])
          stdout, stderr, status = DocsCodeExamples.run(source)
          expect(status).to be_success, lambda { <<~MSG }
              Ruby exited #{status.exitstatus}.

              --- stderr ---
              #{stderr}
              --- stdout ---
              #{stdout}
              --- source (with injected setup) ---
              #{source}
            MSG
        end
      end
    end
  end
end
