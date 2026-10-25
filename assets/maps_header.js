(() => {
  // Collapse the listing, but retain Google's map, branding and attribution.
  const collapse = document.querySelector('button[aria-label="Collapse side panel"]');
  if (collapse) collapse.click();
  if (!document.getElementById('mockareel-header-style')) {
    const style = document.createElement('style');
    style.id = 'mockareel-header-style';
    style.textContent = `
      #omnibox-container, #searchbox, .app-horizontal-widget-holder,
      .scene-footer-container .widget-scene-imagery-container,
      button[aria-label="Expand side panel"], .gb_Q,
      [aria-label="Available search options for this area"],
      [aria-label="Google apps"], [aria-label="Sign in"] {
        visibility: hidden !important;
      }
    `;
    document.head.appendChild(style);
  }
  const visible = e => {
    const r = e.getBoundingClientRect();
    return r.width > 100 && r.height > 100;
  };
  const canvas = [...document.querySelectorAll('canvas')].find(visible);
  const text = document.body.innerText;
  const interaction = /Before you continue|unusual traffic|verify you are human/i.test(text) || location.hostname === 'consent.google.com';
  return JSON.stringify({
    state: interaction ? 'interaction' : canvas && /Map data|Imagery|Terms/.test(text) ? 'ready' : 'loading',
    href: location.href,
  });
})()
