# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Mail links: a link token pair with a mailto: destination around
        # the children. Without an address the children stand alone;
        # without visible text the address is written as a bare URL.
        class EmailTag < Tag
          def render(element, interface)
            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            address = element.address
            return tokens unless address

            destination = "mailto:#{address}"
            return [Inline::Tokens.bare_url(destination)] unless Inline::Tokens.visible?(tokens)

            tokens.unshift(Inline::Tokens.link_open(destination)) << Inline::Tokens.link_close
          end
        end
      end
    end
  end
end
