// Overflowing tables need a keyboard focus target for horizontal scrolling.
(() => {
  const observer = new ResizeObserver((entries) => {
    for (const { target } of entries) {
      if (target.scrollWidth > target.clientWidth) {
        target.setAttribute('tabindex', '0');
      } else {
        target.removeAttribute('tabindex');
      }
    }
  });

  function observeTables() {
    observer.disconnect();
    document.querySelectorAll('.sl-markdown-content table').forEach((table) => {
      observer.observe(table);
    });
  }

  observeTables();
  document.addEventListener('astro:page-load', observeTables);
})();
