# frozen_string_literal: true

module Markbridge
  # Raised when a post holds something whose output depends on a plugin
  # of the target site and the renderer was not told whether the site
  # has it. See the +features:+ option of {Markbridge.discourse_renderer}.
  class UndecidedFeatureError < StandardError
  end
end
