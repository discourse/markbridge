# frozen_string_literal: true

require_relative "discourse_markdown/code_block_tracker"
require_relative "discourse_markdown/detectors/base"
require_relative "discourse_markdown/detectors/mention"
require_relative "discourse_markdown/detectors/poll"
require_relative "discourse_markdown/detectors/event"
require_relative "discourse_markdown/detectors/upload"
require_relative "discourse_markdown/scanner"

module Markbridge
  module Processors
    module DiscourseMarkdown
    end
  end
end
