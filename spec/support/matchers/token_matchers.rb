# frozen_string_literal: true

RSpec::Matchers.define :match_text_token do |expected_text|
  match do |token|
    token.is_a?(Markbridge::Parsers::BBCode::TextToken) && token.text == expected_text
  end

  failure_message do |token|
    "expected text token with text #{expected_text.inspect}, got #{token.inspect}"
  end
end

RSpec::Matchers.define :match_tag_start do |expected_tag, expected_attrs = {}|
  match do |token|
    token.is_a?(Markbridge::Parsers::BBCode::TagStartToken) && token.tag == expected_tag &&
      token.attrs == expected_attrs
  end

  failure_message do |token|
    "expected tag_start token [#{expected_tag}] with attrs #{expected_attrs.inspect}, got #{token.inspect}"
  end
end

RSpec::Matchers.define :match_tag_end do |expected_tag|
  match do |token|
    token.is_a?(Markbridge::Parsers::BBCode::TagEndToken) && token.tag == expected_tag
  end

  failure_message { |token| "expected tag_end token [/#{expected_tag}], got #{token.inspect}" }
end
