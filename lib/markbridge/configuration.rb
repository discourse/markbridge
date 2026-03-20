# frozen_string_literal: true

module Markbridge
  class Configuration
    attr_accessor :escape_hard_line_breaks

    def initialize
      @escape_hard_line_breaks = false
    end
  end
end
