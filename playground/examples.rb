# frozen_string_literal: true

module Markbridge
  module Playground
    module Examples
      module_function

      def catalog
        bbcode_examples + html_examples + text_formatter_examples + media_wiki_examples
      end

      def bbcode_examples
        [
          example(
            id: "bbcode-coverage",
            format: "bbcode",
            scenario: "coverage",
            description: "Every supported BBCode tag in one input",
            highlights: %w[
              quote
              bold
              italic
              underline
              strikethrough
              superscript
              subscript
              url
              email
              color
              size
              spoiler
              code
              image
              attachment
              list
              align
              br
              hr
            ],
            input: <<~BBCODE.strip,
              [quote="alice, post:12, topic:34"]
              [b]Bold[/b], [i]italic[/i], [u]underline[/u], [s]strike[/s], [sup]sup[/sup], [sub]sub[/sub]

              [url=https://example.com/docs]Link text[/url] and [email]team@example.com[/email]
              [color=crimson]red text[/color] [size=22]large text[/size] [spoiler=Reveal]hidden note[/spoiler]

              [code=ruby]puts "hello"
              puts "world"[/code]

              [left]Left lane[/left]
              [center]Centered lane[/center]
              [right]Right lane[/right]
              [justify]Justified lane[/justify]

              [list]
              [*]First item
              [*]Second item with [img=320x180]https://example.com/image.png[/img]
              [list=1]
              [*][attachment=0]diagram.png[/attachment]
              [*]Nested ordered item
              [/list]
              [/list]

              After the break[br]on a new line.
              [hr]
              [/quote]
            BBCODE
          ),
          example(
            id: "bbcode-deep-nesting",
            format: "bbcode",
            scenario: "deep_nesting",
            description: "Quotes, lists, and spoilers stacked 3 levels deep",
            highlights: %w[quote list spoiler color url bold italic code],
            input: <<~BBCODE.strip,
              [quote=Outer]
              [list]
              [*][b]Level 1[/b]
              [list=1]
              [*][i]Level 2[/i]
              [list]
              [*][spoiler=Reveal][color=teal]Level 3 with [url=https://example.com]link[/url][/color][/spoiler]
              [*][code]nested_code()[/code]
              [/list]
              [/list]
              [/list]
              [/quote]
            BBCODE
          ),
          example(
            id: "bbcode-graceful-degradation",
            format: "bbcode",
            scenario: "graceful_degradation",
            description: "Unknown [mystery] stripped, known children preserved",
            highlights: %w[unknown_tags bold italic list quote],
            input: <<~BBCODE.strip,
              [mystery foo=1]
              Known [b]child[/b] should survive.
              [list]
              [*]This list still renders
              [/list]
              [/mystery]

              [quote]
              [unknown]Quoted [i]content[/i][/unknown]
              [/quote]
            BBCODE
          ),
          example(
            id: "bbcode-markdown-escaper",
            format: "bbcode",
            scenario: "markdown_escaper",
            description: "Literal #, -, `, ~~ survive as plain text",
            highlights: %w[markdown_escaper headings lists links code html autolink],
            input: <<~BBCODE.strip,
              [b]Real BBCode still works[/b]
              # not a heading
              - not a bullet
              1. not an ordered list
              [link](https://example.com) should stay literal
              `inline code` and ~~strike~~ should stay literal
              <div class="note">literal html</div>
              <https://example.com> should remain clickable
            BBCODE
          ),
          example(
            id: "bbcode-reordering",
            format: "bbcode",
            scenario: "reordering",
            description: "Mismatched [b][i]...[/b][/i] close order",
            highlights: %w[auto_close reordering bold italic underline list],
            input: <<~BBCODE.strip,
              [b]bold [i]italic [u]underline[/b] still here[/i][/u]

              [list]
              [*][b]List item [i]with mismatched closing[/b] tags[/i]
              [/list]
            BBCODE
          ),
        ]
      end

      def html_examples
        [
          example(
            id: "html-coverage",
            format: "html",
            scenario: "coverage",
            description: "Every supported HTML element in one input",
            highlights: %w[
              paragraph
              strong
              em
              underline
              del
              sup
              sub
              a
              img
              code
              pre
              blockquote
              ul
              ol
              li
              br
              hr
            ],
            input: <<~HTML.strip,
              <blockquote>
                <p><strong>Bold</strong>, <em>italic</em>, <u>underline</u>, <del>strike</del>, H<sub>2</sub>O and E = mc<sup>2</sup></p>
                <p><a href="https://example.com/docs">Link text</a> and <code>inline_code()</code></p>
                <p><img src="https://example.com/image.png" width="320" height="180" alt="Demo image"></p>
                <pre class="ruby">puts "hello"
              puts "world"</pre>
                <ul>
                  <li>First item</li>
                  <li>Second item
                    <ol>
                      <li>Nested ordered</li>
                      <li>Another nested ordered</li>
                    </ol>
                  </li>
                </ul>
                <p>After the break<br>on a new line.</p>
                <hr>
              </blockquote>
            HTML
          ),
          example(
            id: "html-deep-nesting",
            format: "html",
            scenario: "deep_nesting",
            description: "Blockquotes and lists stacked 3 levels deep",
            highlights: %w[blockquote list strong em code a],
            input: <<~HTML.strip,
              <blockquote>
                <ul>
                  <li><strong>Level 1</strong>
                    <ol>
                      <li><em>Level 2</em>
                        <ul>
                          <li><code>level_3()</code> with <a href="https://example.com">link</a></li>
                        </ul>
                      </li>
                    </ol>
                  </li>
                </ul>
              </blockquote>
            HTML
          ),
          example(
            id: "html-graceful-degradation",
            format: "html",
            scenario: "graceful_degradation",
            description: "Custom elements stripped, known children preserved",
            highlights: %w[unknown_tags strong code list paragraph],
            input: <<~HTML.strip,
              <custom-shell data-mode="loose">
                <p>Unknown wrapper keeps <strong>known</strong> children.</p>
                <mystery-inline>Literal text with <code>code</code></mystery-inline>
                <ul>
                  <li>List still works</li>
                </ul>
              </custom-shell>
            HTML
          ),
          example(
            id: "html-markdown-escaper",
            format: "html",
            scenario: "markdown_escaper",
            description: "Literal #, -, `, ~~ survive as plain text",
            highlights: %w[markdown_escaper headings lists links code html autolink],
            input: <<~HTML.strip,
              <p><strong>Real HTML still works</strong></p>
              <p># not a heading</p>
              <p>- not a bullet</p>
              <p>1. not an ordered list</p>
              <p>[link](https://example.com) should stay literal</p>
              <p>`inline code` and ~~strike~~ should stay literal</p>
              <p>&lt;div class="note"&gt;literal html&lt;/div&gt;</p>
              <p>&lt;https://example.com&gt; should remain clickable</p>
            HTML
          ),
        ]
      end

      def text_formatter_examples
        [
          example(
            id: "text-formatter-coverage",
            format: "text_formatter",
            scenario: "coverage",
            description: "Every supported XML tag in one input",
            highlights: %w[
              P
              QUOTE
              B
              I
              U
              S
              URL
              EMAIL
              COLOR
              SIZE
              SPOILER
              CODE
              ALIGN
              LIST
              LI
              IMG
              ATTACHMENT
              br
            ],
            input: <<~XML.strip,
              <r>
                <QUOTE author="Alice" username="alice" post_id="12" topic_id="34">
                  <P><B>Bold</B>, <I>italic</I>, <U>underline</U>, <S>strike</S></P>
                  <P><URL url="https://example.com/docs">Link text</URL> and <EMAIL email="team@example.com">team@example.com</EMAIL></P>
                  <P><COLOR color="crimson">red text</COLOR> <SIZE size="22">large text</SIZE> <SPOILER title="Reveal">hidden note</SPOILER></P>
                  <CODE lang="ruby">puts "hello"
              puts "world"</CODE>
                  <P><ALIGN alignment="left">Left lane</ALIGN></P>
                  <P><ALIGN alignment="center">Centered lane</ALIGN></P>
                  <P><ALIGN alignment="right">Right lane</ALIGN></P>
                  <P><ALIGN alignment="justify">Justified lane</ALIGN></P>
                  <LIST>
                    <LI>First item</LI>
                    <LI>Second item
                      <LIST type="1">
                        <LI><IMG src="https://example.com/image.png" width="320" height="180"/></LI>
                        <LI><ATTACHMENT id="42" filename="diagram.png"/></LI>
                      </LIST>
                    </LI>
                  </LIST>
                  <P>After the break</P><br/><P>on a new line.</P>
                </QUOTE>
              </r>
            XML
          ),
          example(
            id: "text-formatter-deep-nesting",
            format: "text_formatter",
            scenario: "deep_nesting",
            description: "Quotes, lists, and spoilers stacked 3 levels deep",
            highlights: %w[QUOTE LIST SPOILER COLOR URL B I CODE],
            input: <<~XML.strip,
              <r>
                <QUOTE author="Outer">
                  <LIST>
                    <LI><B>Level 1</B>
                      <LIST type="1">
                        <LI><I>Level 2</I>
                          <LIST>
                            <LI><SPOILER title="Reveal"><COLOR color="teal">Level 3 with <URL url="https://example.com">link</URL></COLOR></SPOILER></LI>
                            <LI><CODE>nested_code()</CODE></LI>
                          </LIST>
                        </LI>
                      </LIST>
                    </LI>
                  </LIST>
                </QUOTE>
              </r>
            XML
          ),
          example(
            id: "text-formatter-graceful-degradation",
            format: "text_formatter",
            scenario: "graceful_degradation",
            description: "Unknown XML elements stripped, known children preserved",
            highlights: %w[unknown_tags P B CODE LIST],
            input: <<~XML.strip,
              <r>
                <UNKNOWN mode="loose">
                  <P>Unknown wrapper keeps <B>known</B> children.</P>
                  <MYSTERY>Literal text with <CODE>code</CODE></MYSTERY>
                  <LIST>
                    <LI>List still works</LI>
                  </LIST>
                </UNKNOWN>
              </r>
            XML
          ),
          example(
            id: "text-formatter-markdown-escaper",
            format: "text_formatter",
            scenario: "markdown_escaper",
            description: "Literal #, -, `, ~~ survive as plain text",
            highlights: %w[markdown_escaper headings lists links code html autolink],
            input: <<~XML.strip,
              <r>
                <P><B>Real XML formatting still works</B></P>
                <P># not a heading</P>
                <P>- not a bullet</P>
                <P>1. not an ordered list</P>
                <P>[link](https://example.com) should stay literal</P>
                <P>`inline code` and ~~strike~~ should stay literal</P>
                <P>&lt;div class="note"&gt;literal html&lt;/div&gt;</P>
                <P>&lt;https://example.com&gt; should remain clickable</P>
              </r>
            XML
          ),
        ]
      end

      def media_wiki_examples
        [
          example(
            id: "media-wiki-coverage",
            format: "media_wiki",
            scenario: "coverage",
            description: "Every supported wikitext feature in one input",
            highlights: %w[
              bold
              italic
              heading
              list
              ordered_list
              hr
              internal_link
              external_link
              code
              pre
              nowiki
              strikethrough
              underline
              sup
              sub
              br
            ],
            input: <<~WIKI.strip,
              = Main Heading =

              '''Bold''', ''italic'', '''''bold italic''''', <u>underline</u>, <s>strike</s>, H<sub>2</sub>O and E = mc<sup>2</sup>

              == Links and Code ==
              [[Main Page|Internal link]] and [https://example.com/docs external link]

              <code>inline_code()</code> and a preformatted block:

               puts "hello"
               puts "world"

              === Lists ===
              * First item
              * Second item
              ** Nested bullet

              # First ordered
              # Second ordered
              ## Nested ordered

              Text with <nowiki>'''not bold''' and [[not a link]]</nowiki> preserved.

              ----
            WIKI
          ),
          example(
            id: "media-wiki-deep-nesting",
            format: "media_wiki",
            scenario: "deep_nesting",
            description: "Lists with links and formatting stacked 3 levels deep",
            highlights: %w[list bold italic code internal_link external_link],
            input: <<~WIKI.strip,
              * '''Level 1''' item
              ** ''Level 2'' with [[Page|link]]
              *** Level 3 with <code>nested_code()</code> and [https://example.com external]

              # '''Ordered level 1'''
              ## ''Ordered level 2''
              ### Ordered level 3 with [[Deep Page]]
            WIKI
          ),
          example(
            id: "media-wiki-graceful-degradation",
            format: "media_wiki",
            scenario: "graceful_degradation",
            description: "<mystery> tags ignored, known children preserved",
            highlights: %w[unknown_tags bold italic code list],
            input: <<~WIKI.strip,
              <mystery>
              Known '''bold''' child should survive.
              * This list still renders
              </mystery>

              Text with <unknown>''italic'' content</unknown> here.
            WIKI
          ),
          example(
            id: "media-wiki-markdown-escaper",
            format: "media_wiki",
            scenario: "markdown_escaper",
            description: "Literal #, -, `, ~~ survive as plain text",
            highlights: %w[markdown_escaper headings lists links code html autolink nowiki],
            input: <<~WIKI.strip,
              '''Real wikitext still works'''

              <nowiki># not a heading
              - not a bullet
              1. not an ordered list
              [link](https://example.com) should stay literal
              `inline code` and ~~strike~~ should stay literal
              <div class="note">literal html</div>
              <https://example.com> should remain clickable</nowiki>
            WIKI
          ),
        ]
      end

      def example(id:, format:, scenario:, description:, highlights:, input:)
        { id:, format:, scenario:, description:, highlights:, input: }
      end
    end
  end
end
