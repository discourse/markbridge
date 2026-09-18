// Click-to-zoom for embedded diagrams.
//
// Uses a native <dialog> element opened with showModal() so the zoom
// surface lands in the browser's top layer, immune to ancestor
// transforms (Starlight's view-transition wrapper would otherwise
// break `position: fixed`).
//
// Event-delegation on document so we don't depend on when each
// figure mounts (Astro view transitions can swap them mid-session).

(() => {
  let dialog = null;
  let content = null;

  function ensureDialog() {
    if (dialog) return dialog;
    dialog = document.createElement('dialog');
    dialog.className = 'diagram-zoom-dialog';
    dialog.setAttribute('aria-label', 'Enlarged diagram');
    content = document.createElement('div');
    content.className = 'diagram-zoom-content';
    dialog.appendChild(content);
    const close = document.createElement('button');
    close.type = 'button';
    close.className = 'diagram-zoom-close';
    close.textContent = 'Close diagram';
    close.addEventListener('click', () => dialog.close());
    dialog.appendChild(close);
    dialog.addEventListener('click', (event) => {
      if (event.target === dialog) dialog.close();
    });
    document.body.appendChild(dialog);
    return dialog;
  }

  function visibleImg(figure) {
    return [...figure.querySelectorAll('img')].find(
      (el) => el.offsetParent !== null,
    );
  }

  function openZoom(figure) {
    const img = visibleImg(figure);
    if (!img) return;
    ensureDialog();
    content.innerHTML = '';
    const clone = img.cloneNode(true);
    clone.removeAttribute('class');
    clone.style.maxWidth = '100%';
    clone.style.maxHeight = '100%';
    clone.style.height = 'auto';
    clone.style.width = 'auto';
    content.appendChild(clone);
    dialog.showModal();
  }

  function prepareDiagrams() {
    document.querySelectorAll('figure.diagram').forEach((figure) => {
      if (figure.querySelector('button')) return;
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'diagram-zoom-trigger';
      button.setAttribute('aria-label', 'Enlarge diagram');
      button.setAttribute('aria-haspopup', 'dialog');
      button.append(...figure.childNodes);
      figure.appendChild(button);
    });
  }

  prepareDiagrams();
  document.addEventListener('astro:page-load', prepareDiagrams);

  document.addEventListener('click', (event) => {
    if (!event.target.closest) return;
    if (event.target.closest('.diagram-zoom-dialog')) return;
    const figure = event.target.closest('figure.diagram');
    if (!figure) return;
    openZoom(figure);
  });
})();
