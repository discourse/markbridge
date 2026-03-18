(() => {
  const { examples, initialExampleId, initialResult } = window.playgroundData;

  const formatList = document.querySelector("#format-list");
  const exampleList = document.querySelector("#example-list");
  const viewTabs = document.querySelector("#view-tabs");
  const sourceInput = document.querySelector("#source-input");
  const renderButton = document.querySelector("#render-button");
  const resetButton = document.querySelector("#reset-button");
  const expandTreeButton = document.querySelector("#expand-tree-button");
  const collapseTreeButton = document.querySelector("#collapse-tree-button");
  const astTree = document.querySelector("#ast-tree");
  const markdownOutput = document.querySelector("#markdown-output");
  const copyMarkdownButton = document.querySelector("#copy-markdown-button");
  const diagnosticsFooter = document.querySelector("#diagnostics-footer");

  const formatConfig = [
    { value: "bbcode", label: "BBCode", icon: "squareCode" },
    { value: "html", label: "HTML", icon: "fileCode2" },
    { value: "text_formatter", label: "TextFormatter", icon: "fileType2" },
    { value: "media_wiki", label: "MediaWiki", icon: "bookOpen" }
  ];

  const VIEW_TABS = [
    { id: "input", label: "Input", key: "1" },
    { id: "output", label: "Output", key: "2" },
    { id: "ast", label: "AST", key: "3" }
  ];

  // Icons from Lucide (https://lucide.dev) — ISC License
  // Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022
  // as part of Feather (MIT). All other copyright for Lucide are held by
  // Lucide Contributors 2022.
  const ICONS = {
    squareCode: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m10 9-3 3 3 3" /><path d="m14 15 3-3-3-3" /><rect x="3" y="3" width="18" height="18" rx="2" /></svg>',
    fileCode2: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 12.15V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.706.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2h-3.35" /><path d="M14 2v5a1 1 0 0 0 1 1h5" /><path d="m5 16-3 3 3 3" /><path d="m9 22 3-3-3-3" /></svg>',
    fileType2: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 22h6a2 2 0 0 0 2-2V8a2.4 2.4 0 0 0-.706-1.706l-3.588-3.588A2.4 2.4 0 0 0 14 2H6a2 2 0 0 0-2 2v6" /><path d="M14 2v5a1 1 0 0 0 1 1h5" /><path d="M3 16v-1.5a.5.5 0 0 1 .5-.5h7a.5.5 0 0 1 .5.5V16" /><path d="M6 22h2" /><path d="M7 14v8" /></svg>',
    bookOpen: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 7v14" /><path d="M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z" /></svg>',
    chevron: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 18 6-6-6-6" /></svg>',
    generic: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10" /></svg>',
    treePine: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m17 14 3 3.3a1 1 0 0 1-.7 1.7H4.7a1 1 0 0 1-.7-1.7L7 14h-.3a1 1 0 0 1-.7-1.7L9 9h-.2A1 1 0 0 1 8 7.3L12 3l4 4.3a1 1 0 0 1-.8 1.7H15l3 3.3a1 1 0 0 1-.7 1.7H17Z" /><path d="M12 22v-3" /></svg>',
    textCursor: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M17 22h-1a4 4 0 0 1-4-4V6a4 4 0 0 1 4-4h1" /><path d="M7 22h1a4 4 0 0 0 4-4v-1" /><path d="M7 2h1a4 4 0 0 1 4 4v1" /></svg>',
    wholeWord: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="7" cy="12" r="3" /><path d="M10 9v6" /><circle cx="17" cy="12" r="3" /><path d="M14 7v8" /><path d="M22 17v1c0 .5-.5 1-1 1H3c-.5 0-1-.5-1-1v-1" /></svg>',
    bold: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 12h9a4 4 0 0 1 0 8H7a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h7a4 4 0 0 1 0 8" /></svg>',
    italic: '<svg viewBox="0 0 24 24" aria-hidden="true"><line x1="19" x2="10" y1="4" y2="4" /><line x1="14" x2="5" y1="20" y2="20" /><line x1="15" x2="9" y1="4" y2="20" /></svg>',
    underline: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 4v6a6 6 0 0 0 12 0V4" /><line x1="4" x2="20" y1="20" y2="20" /></svg>',
    strikethrough: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M16 4H9a3 3 0 0 0-2.83 4" /><path d="M14 12a4 4 0 0 1 0 8H6" /><line x1="4" x2="20" y1="12" y2="12" /></svg>',
    superscript: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 19 8-8" /><path d="m12 19-8-8" /><path d="M20 12h-4c0-1.5.442-2 1.5-2.5S20 8.334 20 7.002c0-.472-.17-.93-.484-1.29a2.105 2.105 0 0 0-2.617-.436c-.42.239-.738.614-.899 1.06" /></svg>',
    subscript: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m4 5 8 8" /><path d="m12 5-8 8" /><path d="M20 19h-4c0-1.5.44-2 1.5-2.5S20 15.33 20 14c0-.47-.17-.93-.48-1.29a2.11 2.11 0 0 0-2.62-.44c-.42.24-.74.62-.9 1.07" /></svg>',
    palette: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 22a1 1 0 0 1 0-20 10 9 0 0 1 10 9 5 5 0 0 1-5 5h-2.25a1.75 1.75 0 0 0-1.4 2.8l.3.4a1.75 1.75 0 0 1-1.4 2.8z" /><circle cx="13.5" cy="6.5" r=".5" fill="currentColor" /><circle cx="17.5" cy="10.5" r=".5" fill="currentColor" /><circle cx="6.5" cy="12.5" r=".5" fill="currentColor" /><circle cx="8.5" cy="7.5" r=".5" fill="currentColor" /></svg>',
    aLargeSmall: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m15 16 2.536-7.328a1.02 1.02 1 0 1 1.928 0L22 16" /><path d="M15.697 14h5.606" /><path d="m2 16 4.039-9.69a.5.5 0 0 1 .923 0L11 16" /><path d="M3.304 13h6.392" /></svg>',
    eyeOff: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49" /><path d="M14.084 14.158a3 3 0 0 1-4.242-4.242" /><path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143" /><path d="m2 2 20 20" /></svg>',
    alignCenter: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 5H3" /><path d="M17 12H7" /><path d="M19 19H5" /></svg>',
    terminal: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 19h8" /><path d="m4 17 6-6-6-6" /></svg>',
    link: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" /><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" /></svg>',
    mail: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m22 7-8.991 5.727a2 2 0 0 1-2.009 0L2 7" /><rect x="2" y="4" width="20" height="16" rx="2" /></svg>',
    image: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect width="18" height="18" x="3" y="3" rx="2" ry="2" /><circle cx="9" cy="9" r="2" /><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21" /></svg>',
    paperclip: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m16 6-8.414 8.586a2 2 0 0 0 2.829 2.829l8.414-8.586a4 4 0 1 0-5.657-5.657l-8.379 8.551a6 6 0 1 0 8.485 8.485l8.379-8.551" /></svg>',
    upload: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v12" /><path d="m17 8-5-5-5 5" /><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /></svg>',
    messageSquareQuote: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14 14a2 2 0 0 0 2-2V8h-2" /><path d="M22 17a2 2 0 0 1-2 2H6.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 2 21.286V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2z" /><path d="M8 14a2 2 0 0 0 2-2V8H8" /></svg>',
    list: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 5h.01" /><path d="M3 12h.01" /><path d="M3 19h.01" /><path d="M8 5h13" /><path d="M8 12h13" /><path d="M8 19h13" /></svg>',
    chevronRight: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 18 6-6-6-6" /></svg>',
    pilcrow: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M13 4v16" /><path d="M17 4v16" /><path d="M19 4H9.5a4.5 4.5 0 0 0 0 9H13" /></svg>',
    barChart: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 21v-6" /><path d="M12 21V9" /><path d="M19 21V3" /></svg>',
    calendarDays: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 2v4" /><path d="M16 2v4" /><rect width="18" height="18" x="3" y="4" rx="2" /><path d="M3 10h18" /><path d="M8 14h.01" /><path d="M12 14h.01" /><path d="M16 14h.01" /><path d="M8 18h.01" /><path d="M12 18h.01" /><path d="M16 18h.01" /></svg>',
    heading: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 12h12" /><path d="M6 20V4" /><path d="M18 20V4" /></svg>',
    atSign: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4" /><path d="M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8" /></svg>',
    cornerDownLeft: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 4v7a4 4 0 0 1-4 4H4" /><path d="m9 10-5 5 5 5" /></svg>',
    minus: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14" /></svg>'
  };

  let selectedFormat = "bbcode";
  let selectedExampleId = initialExampleId;
  let activeView = "input";
  let lastResult = initialResult;

  function icon(name) {
    return ICONS[name] || ICONS.generic;
  }

  function titleizeScenario(value) {
    return value
      .split("_")
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ");
  }

  function escapeHtml(text) {
    return text
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function formatExamples(format) {
    return examples.filter((example) => example.format === format);
  }

  function currentExample() {
    return examples.find((example) => example.id === selectedExampleId);
  }

  function updateUrl() {
    const example = currentExample();
    if (!example) {
      return;
    }

    const format = example.format.replaceAll("_", "-");
    const scenario = example.scenario.replaceAll("_", "-");
    history.replaceState(null, "", `/${format}/${scenario}`);
  }

  // --- View tab switching ---

  function switchView(viewId) {
    activeView = viewId;
    VIEW_TABS.forEach((tab) => {
      const panel = document.querySelector(`#panel-${tab.id}`);
      const button = viewTabs.querySelector(`[data-view="${tab.id}"]`);
      if (tab.id === viewId) {
        panel.hidden = false;
        button.classList.add("is-active");
        button.setAttribute("aria-selected", "true");
      } else {
        panel.hidden = true;
        button.classList.remove("is-active");
        button.setAttribute("aria-selected", "false");
      }
    });
  }

  function renderViewTabs() {
    viewTabs.innerHTML = "";
    VIEW_TABS.forEach((tab) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `view-tab${tab.id === activeView ? " is-active" : ""}`;
      button.setAttribute("role", "tab");
      button.setAttribute("aria-selected", tab.id === activeView ? "true" : "false");
      button.setAttribute("data-view", tab.id);
      button.innerHTML = `${tab.label} <kbd>${tab.key}</kbd>`;
      button.addEventListener("click", () => switchView(tab.id));
      viewTabs.append(button);
    });
  }

  // --- Format selection (sidebar) ---

  function setSelectedExample(exampleId) {
    selectedExampleId = exampleId;
    const example = currentExample();
    if (!example) {
      return;
    }

    sourceInput.value = example.input;
    updateUrl();
    renderFormatList();
    renderExampleList();
  }

  function renderFormatList() {
    formatList.innerHTML = "";
    formatConfig.forEach((format) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `format-item${format.value === selectedFormat ? " is-active" : ""}`;
      button.innerHTML = `<span class="icon-shell">${icon(format.icon)}</span> ${format.label}`;
      button.addEventListener("click", () => {
        selectedFormat = format.value;
        const nextExample = formatExamples(selectedFormat)[0];
        setSelectedExample(nextExample.id);
        renderSource();
      });
      formatList.append(button);
    });
  }

  function renderExampleList() {
    const items = formatExamples(selectedFormat);
    exampleList.innerHTML = "";

    items.forEach((example) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `example-card${example.id === selectedExampleId ? " is-active" : ""}`;
      button.innerHTML = `
        <div class="example-scenario-heading">${titleizeScenario(example.scenario)}</div>
        <div class="example-name">${escapeHtml(example.description)}</div>
      `;
      button.addEventListener("click", () => {
        setSelectedExample(example.id);
        renderSource();
      });
      exampleList.append(button);
    });
  }

  // --- Rendering ---

  function setButtonBusy(isBusy) {
    renderButton.disabled = isBusy;
    renderButton.textContent = isBusy ? "Rendering..." : "Render";
  }

  function renderDiagnosticsFooter(result) {
    const stats = result.stats || {};
    const diagnostics = result.diagnostics || {};
    const unknownTags = result.unknown_tags || [];

    const statPairs = [
      ["Nodes", stats.node_count],
      ["Depth", stats.max_depth],
      ["Text", stats.text_node_count],
      ["MD Lines", stats.markdown_lines],
      ["In Lines", stats.input_lines]
    ];

    const statsHtml = statPairs
      .map(([label, value]) =>
        `<span class="footer-stat"><span class="footer-stat-label">${label}:</span><span class="footer-stat-value">${value ?? 0}</span></span>`
      )
      .join("");

    let tagsHtml = "";
    if (unknownTags.length > 0) {
      const tagChips = unknownTags
        .map((entry) => `<span class="footer-tag is-warning">${escapeHtml(entry.name)} &times; ${entry.count}</span>`)
        .join("");
      tagsHtml = `<span class="footer-section-label">Unknown:</span> ${tagChips}`;
    }

    let diagHtml = "";
    const diagParts = [];
    if (typeof diagnostics.auto_closed_tags_count === "number" && diagnostics.auto_closed_tags_count > 0) {
      diagParts.push(`Auto-closed: ${diagnostics.auto_closed_tags_count}`);
    }
    if (typeof diagnostics.depth_exceeded_count === "number" && diagnostics.depth_exceeded_count > 0) {
      diagParts.push(`Depth exceeded: ${diagnostics.depth_exceeded_count}`);
    }
    if (Array.isArray(diagnostics.unclosed_raw_tags) && diagnostics.unclosed_raw_tags.length > 0) {
      diagParts.push(`Unclosed raw: ${diagnostics.unclosed_raw_tags.join(", ")}`);
    }
    if (diagParts.length > 0) {
      diagHtml = diagParts.map((part) => `<span class="footer-diagnostic">${escapeHtml(part)}</span>`).join("");
    }

    diagnosticsFooter.className = "diagnostics-footer is-visible";
    diagnosticsFooter.innerHTML = `${statsHtml} ${tagsHtml} ${diagHtml}`;
  }

  function highlightMarkdownLine(line) {
    if (line.length === 0) {
      return '<span class="tok-plain"></span>';
    }

    let html = escapeHtml(line);

    if (/^\s*(```|~~~)/.test(line)) {
      return `<span class="tok-code-fence">${html}</span>`;
    }

    if (/^\s*(?:-{3,}|\*{3,}|_{3,})\s*$/.test(line)) {
      return `<span class="tok-rule">${html}</span>`;
    }

    html = html.replace(/(&lt;!--.*?--&gt;)/g, '<span class="tok-comment">$1</span>');
    html = html.replace(/(&lt;https?:\/\/[^&]*&gt;)/g, '<span class="tok-autolink">$1</span>');
    html = html.replace(/(\[[^\]]+\]\([^)]+\))/g, '<span class="tok-link">$1</span>');
    html = html.replace(/(\[(?:\/)?[A-Za-z][^\]]*\])/g, '<span class="tok-tag">$1</span>');
    html = html.replace(/(`[^`]+`)/g, '<span class="tok-inline-code">$1</span>');
    html = html.replace(/(\*\*[^*]+\*\*)/g, '<span class="tok-strong">$1</span>');
    html = html.replace(/(^|[^\*])(\*[^*\n]+\*)/g, '$1<span class="tok-em">$2</span>');
    html = html.replace(/(~~[^~]+~~)/g, '<span class="tok-del">$1</span>');
    html = html.replace(/(&lt;\/?[^&]+?&gt;)/g, '<span class="tok-html">$1</span>');
    html = html.replace(
      /^(\s*(?:>+|[-+*]|\d+[.)]))(?=\s)/,
      '<span class="tok-prefix">$1</span>'
    );

    return html;
  }

  function renderMarkdown(markdown) {
    const lines = markdown.length === 0 ? [""] : markdown.split("\n");
    markdownOutput.innerHTML = lines
      .map((line, index) => `
        <div class="code-line">
          <span class="code-line-number">${index + 1}</span>
          <span class="code-line-text">${highlightMarkdownLine(line)}</span>
        </div>
      `)
      .join("");
  }

  function nodeIcon(node) {
    return node.icon || "generic";
  }

  function nodePreview(node) {
    if (node.preview) {
      return `<span class="tree-preview">${escapeHtml(node.preview)}</span>`;
    }
    return "";
  }

  function renderTreeNode(node, depth = 0) {
    const hasChildren = Array.isArray(node.children) && node.children.length > 0;
    const attributePills = Object.entries(node.attributes || {})
      .map(([name, value]) => `<span class="tree-pill">${escapeHtml(name)}=${escapeHtml(String(value))}</span>`)
      .join("");
    const countPill = hasChildren ? `<span class="tree-pill">${node.children.length} child${node.children.length === 1 ? "" : "ren"}</span>` : "";
    const rowMarkup = `
      <div class="tree-row is-${node.category}">
        ${hasChildren ? `<span class="tree-toggle">${icon("chevron")}</span>` : '<span class="tree-toggle"></span>'}
        <span class="tree-icon icon-shell is-${node.category}">${icon(nodeIcon(node))}</span>
        <span class="tree-label">${escapeHtml(node.type)}</span>
        ${nodePreview(node)}
        ${countPill}
        ${attributePills}
      </div>
    `;

    if (!hasChildren) {
      const leaf = document.createElement("div");
      leaf.className = "tree-node";
      leaf.innerHTML = rowMarkup;
      return leaf;
    }

    const details = document.createElement("details");
    details.className = "tree-node";
    details.open = depth < 2;

    const summary = document.createElement("summary");
    summary.innerHTML = rowMarkup;
    details.append(summary);

    const branch = document.createElement("div");
    branch.className = "tree-branch tree-children";
    node.children.forEach((child) => {
      branch.append(renderTreeNode(child, depth + 1));
    });
    details.append(branch);
    return details;
  }

  function renderAst(result) {
    const root = result.ast_json;
    astTree.innerHTML = "";

    if (!root) {
      astTree.innerHTML = '<div class="empty-state">No AST data available.</div>';
      return;
    }

    const container = document.createElement("div");
    container.className = "tree-root";
    container.append(renderTreeNode(root, 0));
    astTree.append(container);
  }

  function applyResult(result) {
    lastResult = result;
    renderDiagnosticsFooter(result);
    renderAst(result);
    renderMarkdown(result.markdown || "");
  }

  async function renderSource() {
    setButtonBusy(true);

    try {
      const response = await fetch("/convert", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          format: selectedFormat,
          input: sourceInput.value
        })
      });

      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || "Rendering failed");
      }

      applyResult(result);
      switchView("output");
    } catch (error) {
      astTree.innerHTML = `<div class="empty-state">Error: ${escapeHtml(error.message)}</div>`;
      markdownOutput.innerHTML = "";
      diagnosticsFooter.className = "diagnostics-footer";
      diagnosticsFooter.innerHTML = "";
    } finally {
      setButtonBusy(false);
    }
  }

  function expandTree(open) {
    astTree.querySelectorAll("details").forEach((node, index) => {
      node.open = open ? true : index === 0;
    });
  }

  function copyMarkdown() {
    if (!navigator.clipboard || !lastResult) {
      return;
    }

    navigator.clipboard.writeText(lastResult.markdown || "");
    copyMarkdownButton.textContent = "Copied";
    window.setTimeout(() => {
      copyMarkdownButton.textContent = "Copy";
    }, 1200);
  }

  // --- Keyboard shortcuts ---

  document.addEventListener("keydown", (event) => {
    // Cmd/Ctrl + Enter — render from anywhere
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      renderSource();
      return;
    }

    // Don't handle shortcuts when typing in textarea
    if (event.target === sourceInput) {
      return;
    }

    // 1/2/3 — switch tabs
    const tab = VIEW_TABS.find((t) => t.key === event.key);
    if (tab && !event.metaKey && !event.ctrlKey && !event.altKey) {
      event.preventDefault();
      switchView(tab.id);
    }
  });

  // --- Initialize ---

  function initialize() {
    const initialExample = examples.find((example) => example.id === initialExampleId) || examples[0];
    selectedFormat = initialExample.format;
    selectedExampleId = initialExample.id;
    renderViewTabs();
    renderFormatList();
    renderExampleList();
    sourceInput.value = initialExample.input;
    applyResult(initialResult);
  }

  renderButton.addEventListener("click", renderSource);
  resetButton.addEventListener("click", () => {
    sourceInput.value = currentExample().input;
  });
  expandTreeButton.addEventListener("click", () => expandTree(true));
  collapseTreeButton.addEventListener("click", () => expandTree(false));
  copyMarkdownButton.addEventListener("click", copyMarkdown);

  initialize();
})();
