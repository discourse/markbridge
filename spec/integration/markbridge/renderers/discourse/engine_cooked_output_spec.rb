# frozen_string_literal: true

# What Discourse itself cooks from the renderer's Markdown, per target
# site: the BBCode of the plugins becomes the plugin's HTML where the
# plugin is there, the plain forms cook as Markdown where it is not, and
# the sanitizer keeps what the renderer writes in html_mode.
RSpec.describe "cooked output of the Discourse engine", :discourse_engine do
  def text(value)
    Markbridge::AST::Text.new(value)
  end

  def document(*nodes)
    document = Markbridge::AST::Document.new
    nodes.each { |node| document << node }
    document
  end

  # The Markdown for the site of +profile+, cooked by that site.
  def cook(document, profile:)
    renderer = DiscourseEngineCooker.renderer(profile)
    markdown = Markbridge.render(document, renderer:).markdown
    Nokogiri::HTML5.fragment(DiscourseEngineCooker.cook(markdown, profile:))
  end

  # A table the renderer has to write as HTML, with +nodes+ in a cell.
  def html_table(*nodes)
    table = Markbridge::AST::Table.new
    table << (
      Markbridge::AST::TableRow.new << (Markbridge::AST::TableCell.new << text("a")) <<
        (Markbridge::AST::TableCell.new << text("b"))
    )
    cell = Markbridge::AST::TableCell.new
    nodes.each { |node| cell << node }
    table << (Markbridge::AST::TableRow.new << cell)
    table
  end

  def details(title, content)
    Markbridge::AST::Details.new(title:) << text(content)
  end

  def spoiler(content, title: nil)
    Markbridge::AST::Spoiler.new(title:) << text(content)
  end

  def sized(size, content)
    Markbridge::AST::Size.new(size:) << text(content)
  end

  def colored(color, content)
    Markbridge::AST::Color.new(color:) << text(content)
  end

  context "with every plugin" do
    def cook_all(*nodes)
      cook(document(*nodes), profile: :all)
    end

    it "cooks a details block with its title" do
      cooked = cook_all(details("Show more", "hidden body"))

      expect(cooked.at_css("details > summary").text.strip).to eq("Show more")
      expect(cooked.at_css("details > p").text).to eq("hidden body")
    end

    it "cooks a spoiler in text as an inline spoiler, with the title in front" do
      cooked = cook_all(text("see "), spoiler("hidden", title: "Reveal"))

      expect(cooked.at_css("p").text).to eq("see Reveal: hidden")
      expect(cooked.at_css("p > span.spoiler").text).to eq("hidden")
    end

    it "cooks a spoiler on a line of its own as a block spoiler" do
      cooked = cook_all(spoiler("hidden"))

      expect(cooked.at_css("div.spoiler > p").text).to eq("hidden")
    end

    it "cooks a poll with its options" do
      cooked = cook_all(Markbridge::AST::Poll.new(options: %w[Yes No]))

      expect(cooked.css("div.poll li").map(&:text)).to eq(%w[Yes No])
    end

    it "cooks an event" do
      event =
        Markbridge::AST::Event.new(name: "Meetup", starts_at: "2026-01-01", ends_at: "2026-01-02")

      cooked = cook_all(event)

      expect(cooked.at_css("div.discourse-post-event")["data-name"]).to eq("Meetup")
      expect(cooked.at_css("div.discourse-post-event")["data-end"]).to eq("2026-01-02")
    end

    it "cooks colors and sizes as spans with the style, through discourse-bbcode" do
      cooked = cook_all(colored("red", "a"), text(" "), sized("150", "b"))

      expect(cooked.css("span").map { |span| [span["style"], span.text] }).to eq(
        [%w[color:red a], %w[font-size:150% b]],
      )
    end

    it "cooks the underline BBCode of core" do
      cooked = cook_all(Markbridge::AST::Underline.new << text("under"))

      expect(cooked.at_css("span.bbcode-u").text).to eq("under")
    end

    it "cooks a quote with its author and post" do
      quote =
        Markbridge::AST::Quote.new(username: "alice", post_number: 2, topic_id: 5) << text("quoted")

      cooked = cook_all(quote)

      aside = cooked.at_css("aside.quote")
      expect([aside["data-username"], aside["data-post"], aside["data-topic"]]).to eq(%w[alice 2 5])
      expect(aside.at_css("blockquote > p").text).to eq("quoted")
    end

    it "cooks a mention as its span without a user lookup" do
      cooked = cook_all(text("hi "), Markbridge::AST::Mention.new(name: "alice"))

      expect(cooked.at_css("span.mention").text).to eq("@alice")
    end

    it "keeps the short URL of an upload" do
      image =
        Markbridge::AST::Upload.new(sha1: "abc", filename: "pic.png", type: :image, alt: "pic")
      file = Markbridge::AST::Upload.new(sha1: "def", filename: "f.pdf", type: :attachment)

      cooked = cook_all(image, text(" "), file)

      expect(cooked.at_css("img")["data-orig-src"]).to eq("upload://pic.png")
      expect(cooked.at_css("a.attachment")["data-orig-href"]).to eq("upload://f.pdf")
    end

    it "keeps the dimensions and the link of an upload inside an HTML table" do
      # The upload is a Markdown island in the cell: Discourse reads the
      # dimensions and the attachment marker only from its Markdown, and
      # its sanitizer drops the upload:// href of a raw HTML link.
      image =
        Markbridge::AST::Upload.new(
          sha1: "abc",
          filename: "pic.png",
          alt: "pic",
          dimensions: "64x32",
        )
      file = Markbridge::AST::Upload.new(sha1: "def", filename: "f.pdf", type: :attachment)

      cooked = cook_all(html_table(image), html_table(file))

      image_cooked = cooked.at_css("td img")
      expect([image_cooked["data-orig-src"], image_cooked["width"], image_cooked["height"]]).to eq(
        %w[upload://pic.png 64 32],
      )
      expect(cooked.at_css("td a.attachment")["data-orig-href"]).to eq("upload://f.pdf")
    end

    it "cooks a poll and an event inside an HTML table, with text after them" do
      # The BBCode is a Markdown island in a div in the cell, so Discourse
      # cooks it also first in the cell, and the text after it stays
      # HTML: after a bare island the ~~~ opened a code fence.
      poll = Markbridge::AST::Poll.new(options: %w[Yes No])
      event = Markbridge::AST::Event.new(name: "Meetup", starts_at: "2026-01-01")

      cooked = cook_all(html_table(poll, text("~~~ after")), html_table(event, text("after")))

      poll_cell, event_cell = cooked.css("table").map { |table| table.css("td").last }
      expect(poll_cell.css("div.poll li").map(&:text)).to eq(%w[Yes No])
      expect(poll_cell.text).to end_with("~~~ after")
      expect(event_cell.at_css("div.discourse-post-event")["data-name"]).to eq("Meetup")
      expect(event_cell.text).to end_with("after")
      expect(cooked.css("pre")).to be_empty
    end

    it "keeps a colon right after a color or size tag at the start of a line" do
      # `[color=red]:x` is a link reference definition otherwise.
      item = Markbridge::AST::ListItem.new << colored("red", ":x")
      list = Markbridge::AST::List.new << item

      cooked = cook_all(list, sized("150", ":y"))

      expect(cooked.at_css("li span[style]").text).to eq(":x")
      expect(cooked.css("p span[style]").map(&:text)).to eq([":y"])
    end

    it "keeps two dashes apart that meet across two text pieces" do
      # Inside a link Discourse writes BBCode as text, so `x-` and `-y`
      # meet; the typographer turns `--` into a dash.
      link = Markbridge::AST::Url.new(href: "https://example.com")
      link << text("x-") << (Markbridge::AST::Underline.new << text("-y"))

      cooked = cook_all(link)

      expect(cooked.at_css("a").text).to eq("x--y")
    end

    it "writes a size inside a link as text, Discourse does not cook BBCode there" do
      link = Markbridge::AST::Url.new(href: "https://example.com") << sized("150", "x")

      cooked = cook_all(link)

      expect(cooked.at_css("a").text).to eq("x")
      expect(cooked.css("span")).to be_empty
    end

    it "keeps the html_mode forms inside an HTML table" do
      cooked =
        cook_all(
          html_table(details("More", "body")),
          html_table(spoiler("hidden")),
          html_table(colored("red", "a")),
        )

      expect(cooked.at_css("td > details > summary").text).to eq("More")
      expect(cooked.at_css("td > span.spoiler").text).to eq("hidden")
      expect(cooked.at_css("td > span[style]")["style"]).to eq("color:red")
    end
  end

  context "with a stock install" do
    def cook_stock(*nodes)
      cook(document(*nodes), profile: :stock)
    end

    it "cooks the bundled plugins" do
      cooked =
        cook_stock(
          details("More", "body"),
          spoiler("hidden"),
          Markbridge::AST::Poll.new(options: %w[A]),
        )

      expect(cooked.at_css("details > summary").text.strip).to eq("More")
      expect(cooked.at_css("div.spoiler").text.strip).to eq("hidden")
      expect(cooked.css("div.poll li").map(&:text)).to eq(%w[A])
    end

    it "shows the event BBCode as text until the events plugin is on" do
      cooked = cook_stock(Markbridge::AST::Event.new(name: "Meetup", starts_at: "2026-01-01"))

      expect(cooked.css("div.discourse-post-event")).to be_empty
      expect(cooked.text).to include("[event")
    end

    it "writes colors and sizes as their text" do
      cooked = cook_stock(colored("red", "a"), text(" "), sized("150", "b"))

      expect(cooked.at_css("p").text).to eq("a b")
      expect(cooked.css("span")).to be_empty
    end
  end

  context "without the plugins" do
    def cook_none(*nodes)
      cook(document(*nodes), profile: :none)
    end

    it "cooks the plain form of a details block" do
      cooked = cook_none(details("Show more", "hidden body"))

      expect(cooked.css("p").map(&:text)).to eq(["Show more", "hidden body"])
      expect(cooked.at_css("p > strong").text).to eq("Show more")
    end

    it "cooks the plain form of a spoiler" do
      cooked = cook_none(text("see "), spoiler("hidden", title: "Reveal"))

      expect(cooked.at_css("p").text).to eq("see Reveal: hidden")
    end

    it "cooks the plain form of a poll" do
      cooked = cook_none(Markbridge::AST::Poll.new(options: %w[Yes No]))

      expect(cooked.css("ul > li").map(&:text)).to eq(%w[Yes No])
    end

    it "cooks the plain form of an event" do
      cooked = cook_none(Markbridge::AST::Event.new(name: "Meetup", starts_at: "2026-01-01"))

      expect(cooked.at_css("p").text).to eq("Meetup, 2026-01-01")
    end

    it "cooks the plain forms inside an HTML table" do
      cooked = cook_none(html_table(details("More", "body")), html_table(spoiler("hidden")))

      cells = cooked.css("td").map(&:text)
      expect(cooked.at_css("td > div > p > strong").text).to eq("More")
      expect(cells).to include("Morebody").and include("hidden")
      expect(cooked.css("details, span.spoiler")).to be_empty
    end

    it "strips a raw <details> and a styled span, which is why the plain forms are Markdown" do
      cooked =
        Nokogiri::HTML5.fragment(
          DiscourseEngineCooker.cook(
            %(<details><summary>T</summary>x</details> <span style="color:red">y</span>),
            profile: :none,
          ),
        )

      expect(cooked.css("details")).to be_empty
      expect(cooked.at_css("span")["style"]).to be_nil
    end
  end
end
