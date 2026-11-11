# frozen_string_literal: true

require "json"
require "open3"

# One long-running Node process that cooks Markdown: a cook.mjs script
# that reads a JSON line with an id and the Markdown and answers with a
# JSON line with the same id and the HTML. MarkdownItCooker,
# DiscourseEngineCooker and the playground cook through it.
#
# The process starts with the first cook and ends when Ruby exits. A
# cook holds a lock while it talks to the process, because the
# playground answers requests on several threads.
class CookProcess
  # @return [Boolean] whether there is a node on the PATH
  def self.node?
    ENV
      .fetch("PATH", "")
      .split(File::PATH_SEPARATOR)
      .any? { |dir| File.executable?(File.join(dir, "node")) }
  end

  # @param command [Array<String>] the script and its arguments, for node
  def initialize(*command)
    @command = command
    @lock = Mutex.new
    @pipes = nil
    @next_id = 0
  end

  # @param markdown [String]
  # @return [String] the HTML the script cooks from +markdown+
  # @raise [RuntimeError] when the script stops without an answer. The
  #   next cook starts it again.
  def cook(markdown)
    @lock.synchronize do
      id = (@next_id += 1)
      answer = JSON.parse(ask(JSON.generate(id:, markdown:), markdown))
      raise "cook.mjs answered request #{answer["id"]}, expected #{id}" unless answer["id"] == id

      answer.fetch("html")
    end
  end

  private

  def ask(request, markdown)
    stdin, stdout = @pipes ||= start
    stdin.puts(request)
    stdout.gets or raise Errno::EPIPE
  rescue Errno::EPIPE
    @pipes = nil
    raise "cook.mjs stopped without an answer for #{markdown.inspect}"
  end

  def start
    stdin, stdout, thread = Open3.popen2("node", *@command)
    stdin.set_encoding(Encoding::UTF_8)
    stdout.set_encoding(Encoding::UTF_8)
    stdin.sync = true
    at_exit do
      stdin.close unless stdin.closed?
      thread.join
    end

    [stdin, stdout]
  end
end
