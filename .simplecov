# frozen_string_literal: true

return unless ENV["COVERAGE"]

SimpleCov.start do
  add_filter "/examples/"
  add_filter "/spec/"
end
