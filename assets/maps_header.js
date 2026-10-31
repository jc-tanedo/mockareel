(() => {
  const text = document.body.innerText;
  const interaction = /Before you continue|unusual traffic|verify you are human/i.test(text) || location.hostname === 'consent.google.com';
  if (!interaction) {
    // Hide browser controls, not map pixels, pins, Google branding or legal text.
    // Keep their DOM nodes so the editor's external zoom buttons still work.
    const containers = `
      #omnibox-container, #searchbox, .app-horizontal-widget-holder,
      #minimap, #runway, .app-viewcard-strip,
      .widget-minimap, .widget-runway, .widget-reveal-card,
      .widget-zoom, .widget-mylocation, .widget-compass, .widget-rotate,
      .widget-fullscreen,
      .scene-footer-container .widget-scene-imagery-container,
      button[aria-label="Expand side panel"], .gb_Q,
      [aria-label="Available search options for this area"],
      [aria-label="Google apps"], [aria-label="Sign in"]
    `;
    const css = `${containers}, [data-mockareel-header-ui] {
      visibility: hidden !important;
      pointer-events: none !important;
    }`;
    let style = document.getElementById('mockareel-header-style');
    if (!style) {
      style = document.createElement('style');
      style.id = 'mockareel-header-style';
      document.head.appendChild(style);
    }
    if (style.textContent !== css) style.textContent = css;

    // Accessible names cover newer Maps layouts whose classes are obfuscated.
    // Maps navigation is localized to English by MapsWebSession.
    const control = /^(?:zoom (?:in|out)\b|(?:show )?your location\b|my location\b|layers\b|(?:show |hide )?(?:imagery|street view)\b|drag pegman\b|(?:enter |exit )?full ?screen\b|rotate (?:the )?(?:map|view)\b|tilt (?:the )?(?:map|view)\b|reset (?:the )?(?:map|view|bearing)\b|map tools\b|search this area\b|see nearby attractions\b)/i;
    const clean = () => {
      const collapse = document.querySelector('button[aria-label="Collapse side panel"]');
      if (collapse && collapse.getBoundingClientRect().width > 0 &&
          getComputedStyle(collapse).visibility !== 'hidden') collapse.click();
      for (const node of document.querySelectorAll('button, [role="button"]')) {
        const labels = ['aria-label', 'data-tooltip', 'title'].map(name => node.getAttribute(name) || '');
        if (labels.some(label => control.test(label.trim())) && !node.hasAttribute('data-mockareel-header-ui')) {
          node.setAttribute('data-mockareel-header-ui', '');
        }
      }
    };
    clean();
    // Google adds/replaces controls after loading, zooming and panning. Keep the
    // cleanup active after the readiness poll finishes, until this page closes.
    if (!window.__mockareelHeaderObserver) {
      const observer = new MutationObserver(clean);
      observer.observe(document.body, {
        childList: true, subtree: true, attributes: true,
        attributeFilter: ['aria-label', 'data-tooltip', 'title', 'class'],
      });
      window.__mockareelHeaderObserver = observer;
    }
  }
  const visible = e => {
    const r = e.getBoundingClientRect();
    return r.width > 100 && r.height > 100;
  };
  const canvas = [...document.querySelectorAll('canvas')].find(visible);
  const tiles = [...document.querySelectorAll('img')].some(node =>
    node.complete && node.naturalWidth > 0 && visible(node) &&
    /(?:\/maps\/(?:vt|api\/staticmap)|\/vt[/?]|\/kh[/?])/.test(node.currentSrc || node.src));
  return JSON.stringify({
    state: interaction ? 'interaction' : canvas || tiles ? 'ready' : 'loading',
    href: location.href,
  });
})()
