# frozen_string_literal: true

require "json"
require_relative "line_process"

# Parses text with s9e\TextFormatter itself, the library whose XML the
# TextFormatter parser reads and whose BBCode rules the BBCode parser
# follows. One PHP process (spec/support/s9e/parse.php) parses
# everything for a run.
#
# It needs PHP with the dom extension and a checkout of s9e in
# tmp/s9e, which `bin/s9e-setup` makes. Guard example groups with
# +S9eParser::SKIP_REASON+; with S9E_REQUIRED=1 a missing PHP or
# checkout fails the examples instead of skipping them.
module S9eParser
  SCRIPT = File.expand_path("s9e/parse.php", __dir__)
  DIRECTORY = File.expand_path("../../tmp/s9e", __dir__)
  SETUP = "bin/s9e-setup"

  def self.missing
    if !LineProcess.program?("php")
      "php is not on the PATH"
    elsif !File.file?(File.join(DIRECTORY, "vendor", "autoload.php"))
      "s9e\\TextFormatter is not in tmp/s9e, run `#{SETUP}`"
    end
  end

  REQUIRED = ENV["S9E_REQUIRED"] == "1"
  SKIP_REASON = (missing unless REQUIRED)

  @process = nil

  # @param text [String]
  # @return [String] the XML s9e stores for +text+, with the BBCodes of
  #   the "bbcodes" profile (spec/support/s9e/profiles.php)
  def self.parse(text)
    process.ask(text:).fetch("xml")
  end

  def self.process
    @process ||=
      begin
        reason = missing
        raise "s9e parser: #{reason}" if reason

        LineProcess.new("php", SCRIPT, DIRECTORY, "bbcodes")
      end
  end

  private_class_method :process
end
