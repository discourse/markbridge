# frozen_string_literal: true

require "json"
require "open3"

# One long-running process of another language that answers requests:
# a JSON object per line on its stdin, with an id, and a JSON object
# per line on its stdout, with the same id. The Node scripts that cook
# Markdown (MarkdownItCooker, DiscourseEngineCooker, the playground)
# and the PHP script that parses with s9e\TextFormatter (S9eParser)
# are such processes.
#
# The process starts with the first request and ends when Ruby exits.
# A request holds a lock while it talks to the process, because the
# playground answers requests on several threads.
class LineProcess
  # @param program [String]
  # @return [Boolean] whether the program is on the PATH
  def self.program?(program)
    ENV
      .fetch("PATH", "")
      .split(File::PATH_SEPARATOR)
      .any? { |dir| File.executable?(File.join(dir, program)) }
  end

  # @param command [Array<String>] the program and its arguments
  def initialize(*command)
    @command = command
    @lock = Mutex.new
    @pipes = nil
    @next_id = 0
  end

  # @param request [Hash] what the script reads, without the id
  # @return [Hash] the answer of the script
  # @raise [RuntimeError] when the script stops without an answer. The
  #   next request starts it again.
  def ask(**request)
    @lock.synchronize do
      id = (@next_id += 1)
      answer = JSON.parse(exchange(JSON.generate(id:, **request), request))
      unless answer["id"] == id
        raise "#{@command.first} answered request #{answer["id"]}, expected #{id}"
      end

      answer
    end
  end

  private

  def exchange(line, request)
    stdin, stdout = @pipes ||= start
    stdin.puts(line)
    stdout.gets or raise Errno::EPIPE
  rescue Errno::EPIPE
    @pipes = nil
    raise "#{@command.join(" ")} stopped without an answer for #{request.inspect}"
  end

  def start
    stdin, stdout, thread = Open3.popen2(*@command)
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
