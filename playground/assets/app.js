(() => {
  const data = JSON.parse(document.querySelector("#playground-data").textContent);
  const { examples, defaults, preview: previewSetup } = data;

  const FORMATS = [
    { id: "bbcode", label: "BBCode", extensions: ["bbcode", "bb"] },
    { id: "html", label: "HTML", extensions: ["html", "htm"] },
    { id: "text_formatter", label: "TextFormatter", extensions: ["xml"] },
    { id: "media_wiki", label: "MediaWiki", extensions: ["wiki", "mediawiki", "wikitext"] }
  ];

  const VIEWS = [
    { id: "markdown", label: "Markdown" },
    { id: "preview", label: "Preview" },
    { id: "ast", label: "AST" }
  ];

  const STORAGE = { draft: "markbridge.playground.draft", options: "markbridge.playground.options", ui: "markbridge.playground.ui" };
  const CONVERT_DELAY = 120;

  const $ = (selector) => document.querySelector(selector);
  const sourceInput = $("#source-input");
  const formatSwitch = $("#format-switch");
  const viewTabs = $("#view-tabs");
  const viewActions = $("#view-actions");
  const markdownView = $("#view-markdown");
  const previewView = $("#view-preview");
  const previewFrame = $("#preview-frame");
  const previewHtml = $("#preview-html");
  const previewNote = $("#preview-note");
  const astView = $("#view-ast");
  const errorView = $("#view-error");
  const examplesDialog = $("#examples-dialog");
  const examplesSearch = $("#examples-search");
  const examplesList = $("#examples-list");
  const issuesButton = $("#issues-button");
  const issuesPopover = $("#issues-popover");
  const sitePopover = $("#site-popover");
  const toast = $("#toast");

  const state = {
    format: "bbcode",
    exampleId: null, // the example the input started from, null for own input
    edited: false,
    // What every format had in the input last, so a switch of the format
    // comes back to it: { exampleId, edited, input } by format.
    buffers: {},
    view: "markdown",
    previewSource: false,
    options: { ...defaults },
    result: null,
    error: null
  };

  // --- Small helpers ---

  function escapeHtml(text) {
    return String(text)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  // Storage is a convenience. A private window or blocked site data must
  // not break the page.
  function load(key) {
    try {
      return JSON.parse(localStorage.getItem(key));
    } catch {
      return null;
    }
  }

  function save(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {
      // nothing to do
    }
  }

  function formatLabel(id) {
    return FORMATS.find((format) => format.id === id)?.label || id;
  }

  function findExample(id) {
    return examples.find((example) => example.id === id);
  }

  function plural(count, one, many) {
    return `${count} ${count === 1 ? one : many}`;
  }

  let toastTimer;
  function showToast(message) {
    toast.textContent = message;
    toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (toast.hidden = true), 1800);
  }

  async function copyText(text, message) {
    try {
      await navigator.clipboard.writeText(text);
      showToast(message);
    } catch {
      showToast("The browser did not allow the copy");
    }
  }

  function encodeInput(text) {
    const bytes = new TextEncoder().encode(text);
    let binary = "";
    bytes.forEach((byte) => (binary += String.fromCharCode(byte)));
    return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
  }

  function decodeInput(encoded) {
    const binary = atob(encoded.replaceAll("-", "+").replaceAll("_", "/"));
    return new TextDecoder().decode(Uint8Array.from(binary, (char) => char.charCodeAt(0)));
  }

  // --- Format ---

  // A guess from the markup itself, for the hint next to the input. It
  // counts what only one of the formats writes.
  const FORMAT_SIGNS = {
    text_formatter: /<(?:[BIUS]|URL|QUOTE|CODE|LIST|LI|IMG|COLOR|SIZE)\b[^>]*>|<[se]>\[|^\s*<[rt]>/g,
    bbcode: /\[\/?(?:b|i|u|s|url|img|quote|code|list|\*|color|size|spoiler|table|tr|td)(?:=[^\]]*)?\]/gi,
    html: /<\/?(?:p|div|br|a|strong|em|span|ul|ol|li|table|tr|td|h[1-6]|blockquote|img)\b[^>]*>/g,
    media_wiki: /'''|\[\[[^\]]+\]\]|^=+[^=\n]+=+\s*$|^\{\||^[*#]+ /gm
  };

  function guessFormat(text) {
    const sample = text.slice(0, 20000);
    const scores = {};
    Object.entries(FORMAT_SIGNS).forEach(([format, signs]) => {
      scores[format] = (sample.match(signs) || []).length;
    });
    // s9e XML is full of BBCode in its <s> and <e> elements, and of tags
    // that look like HTML. Its root element settles it.
    if (/^\s*<[rt]>/.test(sample)) {
      return { format: "text_formatter", scores };
    }
    scores.text_formatter = 0;
    const best = Object.keys(scores).reduce((a, b) => (scores[b] > scores[a] ? b : a));
    return { format: scores[best] >= 2 ? best : null, scores };
  }

  function renderFormatSwitch() {
    formatSwitch.innerHTML = FORMATS.map(
      (format) => `
        <button type="button" role="radio" class="segment" data-format="${format.id}"
          aria-checked="${format.id === state.format}">${format.label}</button>`
    ).join("");
  }

  function updateFormatHint() {
    const hint = $("#format-hint");
    const guess = state.edited ? guessFormat(sourceInput.value) : { format: null };
    const differs = guess.format && guess.format !== state.format && guess.scores[state.format] === 0;
    hint.hidden = !differs;
    if (differs) {
      hint.dataset.format = guess.format;
      $("#format-hint-name").textContent = formatLabel(guess.format);
    }
  }

  // --- Input ---

  function updateSourceName() {
    const example = findExample(state.exampleId);
    const name = example ? example.title : sourceInput.value ? "Your input" : "";
    $("#source-name").textContent = name + (example && state.edited ? ", edited" : "");
    $("#reset-button").hidden = !(example && state.edited);
  }

  function updateUrl() {
    const example = findExample(state.exampleId);
    const path = example ? `/${example.id.replaceAll("_", "-")}` : "/";
    if (location.pathname !== path || location.hash) {
      history.replaceState(null, "", path);
    }
  }

  function saveDraft() {
    state.buffers[state.format] = {
      exampleId: state.exampleId,
      edited: state.edited,
      input: state.edited ? sourceInput.value : null
    };
    save(STORAGE.draft, { format: state.format, buffers: state.buffers });
  }

  // Puts what a format had in the input last back into it.
  // @return {boolean} whether there was edited input to put back
  function restoreBuffer(format) {
    const buffer = state.buffers[format];
    if (!buffer?.edited || typeof buffer.input !== "string") {
      return false;
    }
    state.format = format;
    state.exampleId = findExample(buffer.exampleId) ? buffer.exampleId : null;
    state.edited = true;
    sourceInput.value = buffer.input;
    sourceInput.scrollTop = 0;
    renderFormatSwitch();
    updateUrl();
    inputChanged();
    return true;
  }

  function inputChanged() {
    updateSourceName();
    updateFormatHint();
    saveDraft();
    scheduleConvert();
  }

  function openExample(id) {
    const example = findExample(id);
    if (!example) {
      return;
    }
    state.format = example.format;
    state.exampleId = example.id;
    state.edited = false;
    sourceInput.value = example.input;
    sourceInput.scrollTop = 0;
    renderFormatSwitch();
    updateUrl();
    inputChanged();
  }

  function openOwnInput(text, format) {
    state.exampleId = null;
    state.edited = true;
    if (format) {
      state.format = format;
    }
    sourceInput.value = text;
    sourceInput.scrollTop = 0;
    renderFormatSwitch();
    updateUrl();
    inputChanged();
  }

  // Every format has its own input. The markup of one format is noise
  // to the parser of another, so a switch shows what the new format had
  // last: the edited input, or its example.
  function selectFormat(format) {
    if (format === state.format || restoreBuffer(format)) {
      return;
    }
    const last = findExample(state.buffers[format]?.exampleId);
    const current = findExample(state.exampleId);
    const same = current && findExample(`${format}/${current.slug}`);
    openExample((last || same || examples.find((example) => example.format === format)).id);
  }

  // For input that is in the wrong format: the text stays and goes to
  // the parser of +format+. The format it was in gets its example back.
  function reparseAs(format) {
    const text = sourceInput.value;
    delete state.buffers[state.format];
    openOwnInput(text, format);
  }

  function formatForFile(name, text) {
    const extension = name.split(".").pop().toLowerCase();
    const byExtension = FORMATS.find((format) => format.extensions.includes(extension));
    // An .xml file is s9e XML, but an .html or .txt export can be anything.
    return guessFormat(text).format || byExtension?.id || state.format;
  }

  async function openFile(file) {
    if (!file) {
      return;
    }
    const text = await file.text();
    openOwnInput(text, formatForFile(file.name, text));
    showToast(`Opened ${file.name} as ${formatLabel(state.format)}`);
  }

  function shareLink() {
    if (!state.edited && state.exampleId) {
      return location.origin + location.pathname;
    }
    return `${location.origin}/#${state.format}:${encodeInput(sourceInput.value)}`;
  }

  // --- Converting ---

  let convertTimer;
  let requestNumber = 0;

  function scheduleConvert() {
    clearTimeout(convertTimer);
    convertTimer = setTimeout(convert, CONVERT_DELAY);
  }

  async function convert() {
    clearTimeout(convertTimer);
    const number = ++requestNumber;

    try {
      const response = await fetch("/convert", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ format: state.format, input: sourceInput.value, options: state.options })
      });
      const body = await response.json();
      if (number !== requestNumber) {
        return; // a newer request is on its way
      }
      state.result = response.ok ? body : null;
      state.error = response.ok ? null : body.error || "The conversion failed";
    } catch (error) {
      if (number !== requestNumber) {
        return;
      }
      state.result = null;
      state.error = `The playground server did not answer (${error.message})`;
    }

    renderOutput();
  }

  // --- Output: Markdown ---

  function highlightMarkdownLine(line) {
    let html = escapeHtml(line);

    if (/^\s*(```|~~~)/.test(line)) {
      return `<span class="tok-code">${html}</span>`;
    }
    if (/^\s*(?:-{3,}|\*{3,}|_{3,})\s*$/.test(line)) {
      return `<span class="tok-mark">${html}</span>`;
    }

    html = html.replace(/(&lt;!--.*?--&gt;)/g, '<span class="tok-comment">$1</span>');
    html = html.replace(/(!?\[[^\]]*\]\([^)]+\))/g, '<span class="tok-link">$1</span>');
    html = html.replace(/(\[\/?[A-Za-z][^\]]*\])(?!\()/g, '<span class="tok-tag">$1</span>');
    html = html.replace(/(`[^`]+`)/g, '<span class="tok-code">$1</span>');
    html = html.replace(/(\*\*[^*]+\*\*)/g, '<span class="tok-strong">$1</span>');
    html = html.replace(/(^|[^*\\])(\*[^*\n]+\*)/g, '$1<span class="tok-em">$2</span>');
    html = html.replace(/(~~[^~]+~~)/g, '<span class="tok-del">$1</span>');
    html = html.replace(/(&lt;\/?[a-zA-Z][^&]*?&gt;)/g, '<span class="tok-tag">$1</span>');
    html = html.replace(/^(\s*(?:(?:&gt;\s?)+|[-+*]|\d+[.)]|#{1,6}))(?=\s|$)/, '<span class="tok-mark">$1</span>');
    // Spaces at the end of a line mean something in Markdown (two of them
    // are a hard break), so they get a mark.
    html = html.replace(/([ \t]+)$/, '<span class="tok-trailing">$1</span>');

    return html;
  }

  function codeLines(text, highlight) {
    const lines = text.split("\n");
    return lines
      .map(
        (line, index) =>
          `<div class="code-line"><span class="code-number">${index + 1}</span><span class="code-text">${highlight(line)}</span></div>`
      )
      .join("");
  }

  function renderMarkdown(result) {
    if (result.markdown === "") {
      markdownView.innerHTML = `<div class="empty-state">${
        sourceInput.value ? "The output is empty." : "The Markdown shows up here."
      }</div>`;
      return;
    }
    markdownView.innerHTML = codeLines(result.markdown, highlightMarkdownLine);
  }

  // --- Output: preview ---

  function previewDocument(html) {
    const style = getComputedStyle(document.documentElement);
    const color = (name) => style.getPropertyValue(name).trim();

    return `<!doctype html><html><head><meta charset="utf-8"><base target="_blank"><style>
      :root { color-scheme: light dark; }
      body { margin: 0; padding: 18px 22px 40px; background: ${color("--surface")}; color: ${color("--ink")};
        font: 15px/1.55 ${color("--ui")}; overflow-wrap: anywhere; }
      a { color: ${color("--link")}; }
      p, ul, ol, pre, table, blockquote, aside, details, hr { margin: 0 0 14px; }
      h1, h2, h3, h4, h5, h6 { margin: 22px 0 10px; line-height: 1.25; }
      h1 { font-size: 1.6em; } h2 { font-size: 1.35em; } h3 { font-size: 1.15em; }
      h4, h5, h6 { font-size: 1em; }
      ul, ol { padding-left: 26px; }
      li > ul, li > ol { margin-bottom: 0; }
      blockquote { padding: 10px 14px; border-left: 4px solid ${color("--line-strong")}; background: ${color("--sunken")}; }
      blockquote > :last-child, aside.quote > blockquote > :last-child, td > :last-child { margin-bottom: 0; }
      aside.quote { border-left: 4px solid ${color("--line-strong")}; background: ${color("--sunken")}; }
      aside.quote .title { padding: 10px 14px 0; color: ${color("--muted")}; font-size: 0.9em; }
      aside.quote .title:empty { display: none; }
      aside.quote blockquote { margin: 0; border: 0; background: none; }
      code, pre { font-family: ${color("--mono")}; font-size: 0.88em; }
      code { padding: 1px 4px; border-radius: 3px; background: ${color("--sunken")}; }
      pre { padding: 12px 14px; border-radius: 4px; background: ${color("--sunken")}; overflow: auto; }
      pre code { padding: 0; background: none; font-size: 1em; }
      table { border-collapse: collapse; }
      th, td { padding: 6px 12px; border: 1px solid ${color("--line-strong")}; text-align: left; vertical-align: top; }
      th { background: ${color("--sunken")}; }
      hr { border: 0; border-top: 1px solid ${color("--line-strong")}; }
      img { max-width: 100%; max-height: 220px; width: auto; height: auto; min-width: 24px; min-height: 24px;
        vertical-align: middle; outline: 1px dashed ${color("--line-strong")}; outline-offset: -1px;
        color: ${color("--muted")}; font-size: 0.85em; }
      .bbcode-b { font-weight: bold; } .bbcode-i { font-style: italic; }
      .bbcode-u { text-decoration: underline; } .bbcode-s { text-decoration: line-through; }
      .spoiler, .spoiled { filter: blur(5px); cursor: pointer; transition: filter 120ms; }
      .spoiler:hover, .spoiled:hover { filter: none; }
      details { padding: 8px 12px; border: 1px solid ${color("--line-strong")}; border-radius: 4px; }
      summary { cursor: pointer; }
      .mention, .hashtag { padding: 0 3px; border-radius: 3px; background: ${color("--sunken")}; }
    </style></head><body>${html}</body></html>`;
  }

  function renderPreview(result) {
    const preview = result.preview;
    const problem = !preview ? previewSetup.unavailable || "There is no preview." : preview.error;

    previewNote.hidden = !problem;
    previewFrame.hidden = Boolean(problem) || state.previewSource;
    previewHtml.hidden = Boolean(problem) || !state.previewSource;

    if (problem) {
      previewNote.textContent = preview ? `The preview failed: ${problem}` : problem;
      return;
    }
    if (state.previewSource) {
      previewHtml.innerHTML = codeLines(preview.html, escapeHtml);
    } else if (previewFrame.dataset.html !== preview.html) {
      // Setting srcdoc again reloads the frame and loses the scroll
      // position, so only when the HTML changed.
      previewFrame.dataset.html = preview.html;
      previewFrame.srcdoc = previewDocument(preview.html);
    }
  }

  function previewEngineLabel(result) {
    const preview = result?.preview;
    if (!preview || preview.error) {
      return "";
    }
    return preview.engine === "discourse"
      ? "Cooked by the Discourse engine"
      : "Cooked by markdown-it, which reads no BBCode";
  }

  // --- Output: AST ---

  function attributeHtml(name, value) {
    return `<span class="attr">${escapeHtml(name)}=<span class="attr-value">${escapeHtml(JSON.stringify(value))}</span></span>`;
  }

  function nodeHtml(node, openDepth) {
    const isText = node.kind === "text";
    const attributes = Object.entries(node.attributes || {})
      .filter(([name]) => !(isText && name === "text"))
      .map(([name, value]) => attributeHtml(name, value))
      .join("");
    const text = isText ? `<span class="node-text">${escapeHtml(JSON.stringify(node.attributes.text))}</span>` : "";
    const row = `<span class="node-type is-${node.category}">${escapeHtml(node.type)}</span>${text}${attributes}`;

    if (node.children.length === 0) {
      return `<div class="node"><div class="node-row">${row}</div></div>`;
    }

    const children = node.children.map((child) => nodeHtml(child, openDepth)).join("");
    return `<details class="node"${node.depth < openDepth ? " open" : ""}>
      <summary class="node-row">${row}</summary><div class="node-children">${children}</div></details>`;
  }

  function renderAst(result) {
    // A small tree opens completely, a large one only its first levels.
    const openDepth = result.stats.node_count <= 400 ? Infinity : 3;
    astView.innerHTML = nodeHtml(result.ast_json, openDepth);
  }

  function setTreeOpen(open) {
    astView.querySelectorAll("details").forEach((node, index) => {
      node.open = open || index === 0;
    });
  }

  // --- Output: notes and numbers ---

  const STRATEGIES = {
    hoist_after: "moved out, behind it",
    unwrap: "unwrapped, its content stays",
    textify: "replaced by its text",
    drop: "dropped",
    keep: "kept"
  };

  function collectIssues(result) {
    const diagnostics = result.diagnostics;
    const issues = [];

    if (result.unknown_tags.length > 0) {
      const total = result.unknown_tags.length;
      issues.push({
        summary: plural(total, "unknown tag", "unknown tags"),
        title: "Tags without a handler",
        text: "The tag is dropped, its content stays. The number counts how often the parser saw it.",
        items: result.unknown_tags.map((tag) => `${tag.name} × ${tag.count}`)
      });
    }
    if (diagnostics.auto_closed_tags_count > 0) {
      issues.push({
        summary: `${diagnostics.auto_closed_tags_count} auto-closed`,
        title: `${plural(diagnostics.auto_closed_tags_count, "tag", "tags")} closed by the parser`,
        text: "They were still open when their parent closed, or were closed in the wrong order.",
        items: []
      });
    }
    if (diagnostics.unclosed_raw_tags.length > 0) {
      issues.push({
        summary: plural(diagnostics.unclosed_raw_tags.length, "unclosed raw tag", "unclosed raw tags"),
        title: "Raw tags without an end",
        text: "The rest of the input became their content.",
        items: diagnostics.unclosed_raw_tags.map((tag) => `${tag.name} × ${tag.count}`)
      });
    }
    if (diagnostics.depth_exceeded_count > 0) {
      issues.push({
        summary: "nesting too deep",
        title: `${plural(diagnostics.depth_exceeded_count, "tag", "tags")} beyond the depth limit`,
        text: "The parser keeps them as text.",
        items: []
      });
    }
    if (diagnostics.normalization.length > 0) {
      const total = diagnostics.normalization.reduce((sum, entry) => sum + entry.count, 0);
      issues.push({
        summary: `${total} normalized`,
        title: "Changed by the normalizer",
        text: "Markdown cannot nest these, so the AST was rewritten before rendering. The AST tab shows the tree after it.",
        items: diagnostics.normalization.map(
          (entry) =>
            `${entry.child} in ${entry.parent}: ${STRATEGIES[entry.strategy] || entry.strategy}${entry.count > 1 ? ` × ${entry.count}` : ""}`
        )
      });
    }

    return issues;
  }

  function renderStatus(result) {
    const issues = result ? collectIssues(result) : [];

    issuesButton.hidden = issues.length === 0;
    $("#issues-none").textContent = result && issues.length === 0 ? "No notes from the parser" : "";
    issuesButton.textContent = issues.map((issue) => issue.summary).join(" · ");
    issuesPopover.innerHTML = issues
      .map(
        (issue) => `
          <p class="popover-title">${escapeHtml(issue.title)}</p>
          <p class="popover-text">${escapeHtml(issue.text)}</p>
          ${issue.items.length ? `<ul class="issue-items">${issue.items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>` : ""}`
      )
      .join("");
    if (issues.length === 0 && issuesPopover.matches(":popover-open")) {
      issuesPopover.hidePopover();
    }

    if (!result) {
      $("#stats").textContent = "";
      return;
    }
    const stats = result.stats;
    const number = (value) => value.toLocaleString("en-US");
    $("#stats").textContent = [
      plural(number(stats.node_count), "node", "nodes"),
      `depth ${stats.max_depth}`,
      `${number(stats.input_chars)} → ${number(stats.markdown_chars)} chars`,
      `${stats.duration_ms} ms`
    ].join(" · ");
  }

  // --- Output: tabs ---

  function actionButton(label, action) {
    return `<button type="button" class="link-button" data-action="${action}">${label}</button>`;
  }

  function renderViewActions() {
    const actions = {
      markdown: () => actionButton("Copy", "copy-markdown"),
      preview: () =>
        state.result?.preview && !state.result.preview.error
          ? `<span class="engine-label">${previewEngineLabel(state.result)}</span>` +
            actionButton(state.previewSource ? "Show the page" : "Show the HTML", "toggle-preview-source")
          : "",
      ast: () => actionButton("Expand", "expand-tree") + actionButton("Collapse", "collapse-tree") + actionButton("Copy", "copy-ast")
    };
    viewActions.innerHTML = state.result ? actions[state.view]() : "";
  }

  function renderTabs() {
    viewTabs.innerHTML = VIEWS.map(
      (view) => `
        <button type="button" role="tab" class="tab" data-view="${view.id}"
          aria-selected="${view.id === state.view}">${view.label}</button>`
    ).join("");
  }

  function renderOutput() {
    const { result, error } = state;
    const panels = { markdown: markdownView, preview: previewView, ast: astView };

    errorView.hidden = !error;
    Object.entries(panels).forEach(([id, panel]) => {
      panel.hidden = Boolean(error) || id !== state.view;
    });

    if (error) {
      errorView.innerHTML = `<p class="error-title">The conversion raised an error</p><pre>${escapeHtml(error)}</pre>`;
    } else if (result) {
      ({ markdown: renderMarkdown, preview: renderPreview, ast: renderAst })[state.view](result);
    }

    renderViewActions();
    renderStatus(result);
  }

  function selectView(view) {
    state.view = view;
    save(STORAGE.ui, { ...(load(STORAGE.ui) || {}), view });
    renderTabs();
    renderOutput();
  }

  // --- Example picker ---

  let pickerIndex = 0;
  let pickerItems = [];

  function snippet(input, terms) {
    const lower = input.toLowerCase();
    const position = Math.min(...terms.map((term) => lower.indexOf(term)).filter((index) => index >= 0));
    if (!Number.isFinite(position)) {
      return null;
    }
    const lineStart = input.lastIndexOf("\n", position) + 1;
    const start = Math.max(lineStart, position - 30);
    let line = input.slice(start, start + 90).split("\n")[0];
    let html = escapeHtml(line);
    terms.forEach((term) => {
      const pattern = new RegExp(escapeHtml(term).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "gi");
      html = html.replace(pattern, (match) => `<mark>${match}</mark>`);
    });
    return (start > lineStart ? "…" : "") + html;
  }

  function searchExamples(query) {
    const terms = query.toLowerCase().split(/\s+/).filter(Boolean);

    return examples
      .map((example) => {
        const label = `${example.title} ${example.description} ${formatLabel(example.format)}`.toLowerCase();
        const input = example.input.toLowerCase();
        if (!terms.every((term) => label.includes(term) || input.includes(term))) {
          return null;
        }
        const inLabel = terms.every((term) => label.includes(term));
        const inTitle = terms.every((term) => example.title.toLowerCase().includes(term));
        return {
          example,
          // A match in the title comes first, then one in the description.
          rank: inTitle ? 0 : inLabel ? 1 : 2,
          snippet: terms.length && !inLabel ? snippet(example.input, terms) : null
        };
      })
      .filter(Boolean)
      .sort((a, b) => a.rank - b.rank);
  }

  function renderPicker() {
    const matches = searchExamples(examplesSearch.value);
    // The format in use comes first, the others in their usual order.
    const order = [state.format, ...FORMATS.map((format) => format.id).filter((id) => id !== state.format)];
    pickerItems = order.flatMap((format) => matches.filter((match) => match.example.format === format));
    pickerIndex = Math.min(pickerIndex, Math.max(pickerItems.length - 1, 0));

    if (pickerItems.length === 0) {
      examplesList.innerHTML = '<div class="empty-state">No example has that.</div>';
      return;
    }

    let html = "";
    let group = null;
    pickerItems.forEach((item, index) => {
      const { example } = item;
      if (example.format !== group) {
        group = example.format;
        html += `<div class="picker-group">${formatLabel(group)}</div>`;
      }
      html += `
        <button type="button" role="option" class="picker-item" data-index="${index}"
          aria-selected="${index === pickerIndex}"${example.id === state.exampleId ? ' data-current="true"' : ""}>
          <span class="picker-title">${escapeHtml(example.title)}</span>
          <span class="picker-description">${escapeHtml(example.description)}</span>
          ${item.snippet ? `<code class="picker-snippet">${item.snippet}</code>` : ""}
        </button>`;
    });
    examplesList.innerHTML = html;
    examplesList.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: "nearest" });
  }

  function openPicker() {
    examplesSearch.value = "";
    pickerIndex = 0;
    examplesDialog.showModal();
    renderPicker();
    const current = pickerItems.findIndex((item) => item.example.id === state.exampleId);
    if (current >= 0) {
      pickerIndex = current;
      renderPicker();
    }
    examplesSearch.focus();
  }

  function pickExample(index) {
    const item = pickerItems[index];
    if (!item) {
      return;
    }
    examplesDialog.close();
    openExample(item.example.id);
    sourceInput.focus();
    sourceInput.setSelectionRange(0, 0);
  }

  // --- Site options ---

  function renderOptions() {
    sitePopover.querySelectorAll("[data-option]").forEach((input) => {
      input.checked = state.options[input.dataset.option] === true;
    });
    const changed = Object.keys(defaults).some((key) => state.options[key] !== defaults[key]);
    $("#site-changed").hidden = !changed;
    $("#site-reset").hidden = !changed;
  }

  function setOptions(options) {
    state.options = options;
    save(STORAGE.options, options);
    renderOptions();
    convert();
  }

  // --- Popovers: placed at their button ---

  function placePopover(popover, button, align) {
    popover.addEventListener("toggle", (event) => {
      if (event.newState !== "open") {
        return;
      }
      const anchor = button.getBoundingClientRect();
      const box = popover.getBoundingClientRect();
      const gap = 6;
      if (align === "above") {
        popover.style.top = `${Math.max(8, anchor.top - box.height - gap)}px`;
        popover.style.left = `${Math.max(8, Math.min(anchor.left, innerWidth - box.width - 8))}px`;
      } else {
        popover.style.top = `${anchor.bottom + gap}px`;
        popover.style.left = `${Math.max(8, anchor.right - box.width)}px`;
      }
    });
  }

  // --- Splitter ---

  function setSplit(ratio, persist) {
    const clamped = Math.min(0.8, Math.max(0.2, ratio));
    $("#panes").style.setProperty("--split", `${(clamped * 100).toFixed(2)}%`);
    if (persist) {
      save(STORAGE.ui, { ...(load(STORAGE.ui) || {}), split: clamped });
    }
  }

  function setUpSplitter() {
    const splitter = $("#splitter");
    const panes = $("#panes");
    const ratioAt = (event) => {
      const box = panes.getBoundingClientRect();
      return (event.clientX - box.left) / box.width;
    };

    splitter.addEventListener("pointerdown", (event) => {
      splitter.setPointerCapture(event.pointerId);
      panes.classList.add("is-resizing");
    });
    splitter.addEventListener("pointermove", (event) => {
      if (splitter.hasPointerCapture(event.pointerId)) {
        setSplit(ratioAt(event), false);
      }
    });
    splitter.addEventListener("pointerup", (event) => {
      panes.classList.remove("is-resizing");
      setSplit(ratioAt(event), true);
    });
    splitter.addEventListener("dblclick", () => setSplit(0.5, true));
    splitter.addEventListener("keydown", (event) => {
      const step = { ArrowLeft: -0.02, ArrowRight: 0.02 }[event.key];
      if (step) {
        event.preventDefault();
        const current = parseFloat(panes.style.getPropertyValue("--split")) / 100 || 0.5;
        setSplit(current + step, true);
      }
    });
  }

  // --- Events ---

  formatSwitch.addEventListener("click", (event) => {
    const button = event.target.closest("[data-format]");
    if (button) {
      selectFormat(button.dataset.format);
    }
  });

  sourceInput.addEventListener("input", () => {
    state.edited = true;
    if (!findExample(state.exampleId) || sourceInput.value === "") {
      state.exampleId = null;
      updateUrl();
    }
    inputChanged();
  });

  sourceInput.addEventListener("dragover", (event) => {
    if (event.dataTransfer?.types.includes("Files")) {
      event.preventDefault();
      sourceInput.classList.add("is-drop-target");
    }
  });
  sourceInput.addEventListener("dragleave", () => sourceInput.classList.remove("is-drop-target"));
  sourceInput.addEventListener("drop", (event) => {
    sourceInput.classList.remove("is-drop-target");
    const file = event.dataTransfer?.files[0];
    if (file) {
      event.preventDefault();
      openFile(file);
    }
  });

  $("#reset-button").addEventListener("click", () => openExample(state.exampleId));
  $("#open-button").addEventListener("click", () => $("#file-input").click());
  $("#file-input").addEventListener("change", (event) => {
    openFile(event.target.files[0]);
    event.target.value = "";
  });
  $("#share-button").addEventListener("click", () => copyText(shareLink(), "Link copied"));
  $("#format-hint-switch").addEventListener("click", () => reparseAs($("#format-hint").dataset.format));

  viewTabs.addEventListener("click", (event) => {
    const button = event.target.closest("[data-view]");
    if (button) {
      selectView(button.dataset.view);
    }
  });

  viewActions.addEventListener("click", (event) => {
    const action = event.target.closest("[data-action]")?.dataset.action;
    const result = state.result;
    if (!action || !result) {
      return;
    }
    if (action === "copy-markdown") {
      copyText(result.markdown, "Markdown copied");
    } else if (action === "copy-ast") {
      copyText(result.ast, "AST copied");
    } else if (action === "expand-tree") {
      setTreeOpen(true);
    } else if (action === "collapse-tree") {
      setTreeOpen(false);
    } else if (action === "toggle-preview-source") {
      state.previewSource = !state.previewSource;
      renderOutput();
    }
  });

  $("#examples-button").addEventListener("click", openPicker);
  examplesSearch.addEventListener("input", () => {
    pickerIndex = 0;
    renderPicker();
  });
  examplesSearch.addEventListener("keydown", (event) => {
    const step = { ArrowDown: 1, ArrowUp: -1 }[event.key];
    if (step) {
      event.preventDefault();
      pickerIndex = (pickerIndex + step + pickerItems.length) % Math.max(pickerItems.length, 1);
      renderPicker();
    } else if (event.key === "Enter") {
      event.preventDefault();
      pickExample(pickerIndex);
    }
  });
  examplesList.addEventListener("click", (event) => {
    const item = event.target.closest("[data-index]");
    if (item) {
      pickExample(Number(item.dataset.index));
    }
  });
  // A click on the backdrop closes the dialog.
  examplesDialog.addEventListener("click", (event) => {
    if (event.target === examplesDialog) {
      examplesDialog.close();
    }
  });

  sitePopover.addEventListener("change", (event) => {
    const option = event.target.dataset.option;
    if (option) {
      setOptions({ ...state.options, [option]: event.target.checked });
    }
  });
  $("#site-reset").addEventListener("click", () => setOptions({ ...defaults }));

  document.addEventListener("keydown", (event) => {
    const command = event.metaKey || event.ctrlKey;

    if (command && event.key.toLowerCase() === "k") {
      event.preventDefault();
      if (examplesDialog.open) {
        examplesDialog.close();
      } else {
        openPicker();
      }
      return;
    }

    // Alt+1/2/3 switches the output from anywhere, the plain digit when
    // the focus is not in a field.
    const typing = event.target.matches("textarea, input");
    const digit = event.code.startsWith("Digit") ? Number(event.code.slice(5)) : null;
    if (digit && digit <= VIEWS.length && !command && (event.altKey || !typing) && !examplesDialog.open) {
      event.preventDefault();
      selectView(VIEWS[digit - 1].id);
    }
  });

  // The preview takes its colors from the page, so a theme change
  // needs a new frame.
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    delete previewFrame.dataset.html;
    renderOutput();
  });

  // --- Start ---

  function start() {
    const ui = load(STORAGE.ui) || {};
    if (VIEWS.some((view) => view.id === ui.view)) {
      state.view = ui.view;
    }
    if (ui.split) {
      setSplit(ui.split, false);
    }
    state.options = { ...defaults, ...(load(STORAGE.options) || {}) };

    if (/Mac|iPhone|iPad/.test(navigator.platform)) {
      $("#examples-shortcut").textContent = "⌘K";
    }

    renderTabs();
    renderOptions();
    placePopover(sitePopover, $("#site-button"), "below");
    placePopover(issuesPopover, issuesButton, "above");
    setUpSplitter();

    // What to open, in this order: a shared link, the example in the
    // path, the draft from the last visit, the first example.
    const shared = location.hash.match(/^#([a-z_]+):(.*)$/);
    const [pathFormat, pathSlug] = location.pathname.split("/").filter(Boolean);
    const fromPath = pathFormat
      ? findExample(`${pathFormat.replaceAll("-", "_")}/${pathSlug || "everything"}`)
      : null;
    const draft = load(STORAGE.draft);
    state.buffers = draft?.buffers || {};

    if (shared && FORMATS.some((format) => format.id === shared[1])) {
      try {
        openOwnInput(decodeInput(shared[2]), shared[1]);
        return;
      } catch {
        showToast("The link has no readable input");
      }
    }

    // The input of the last visit, unless the path asks for an example
    // that it was not made from.
    const format = fromPath ? fromPath.format : draft?.format;
    const buffer = state.buffers[format];
    const fits = !fromPath || buffer?.exampleId === fromPath.id;
    if (fits && restoreBuffer(format)) {
      return;
    }
    openExample((fromPath || findExample(buffer?.exampleId) || examples[0]).id);
  }

  start();
})();
