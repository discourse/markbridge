# frozen_string_literal: true

require_relative "discourse/tag"
require_relative "discourse/tag_library"
require_relative "discourse/render_context"
require_relative "discourse/rendering_interface"
require_relative "discourse/markdown_escaper"

# Builders
require_relative "discourse/builders/list_item_builder"

# Tags
require_relative "discourse/tags/align_tag"
require_relative "discourse/tags/attachment_tag"
require_relative "discourse/tags/bold_tag"
require_relative "discourse/tags/code_tag"
require_relative "discourse/tags/color_tag"
require_relative "discourse/tags/email_tag"
require_relative "discourse/tags/heading_tag"
require_relative "discourse/tags/horizontal_rule_tag"
require_relative "discourse/tags/line_break_tag"
require_relative "discourse/tags/image_tag"
require_relative "discourse/tags/italic_tag"
require_relative "discourse/tags/list_tag"
require_relative "discourse/tags/list_item_tag"
require_relative "discourse/tags/paragraph_tag"
require_relative "discourse/tags/quote_tag"
require_relative "discourse/tags/size_tag"
require_relative "discourse/tags/spoiler_tag"
require_relative "discourse/tags/strikethrough_tag"
require_relative "discourse/tags/subscript_tag"
require_relative "discourse/tags/superscript_tag"
require_relative "discourse/tags/table_tag"
require_relative "discourse/tags/table_row_tag"
require_relative "discourse/tags/table_cell_tag"
require_relative "discourse/tags/underline_tag"
require_relative "discourse/tags/url_tag"

# Discourse-specific tags
require_relative "discourse/tags/event_tag"
require_relative "discourse/tags/mention_tag"
require_relative "discourse/tags/poll_tag"
require_relative "discourse/tags/upload_tag"

# Renderer itself
require_relative "discourse/renderer"

module Markbridge
  module Renderers
    module Discourse
    end
  end
end
