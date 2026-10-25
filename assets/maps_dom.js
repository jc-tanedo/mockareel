(() => {
  const text = el => (el?.innerText || el?.textContent || '').replace(/[\uE000-\uF8FF]/g, '').replace(/\u00a0/g, ' ').trim();
  const clean = s => (s || '').replace(/[\uE000-\uF8FF]/g, '').replace(/\s+/g, ' ').trim();
  const label = el => el?.getAttribute('aria-label') || '';
  const body = document.body?.innerText || '';
  const bounded = (s, n = 300) => clean(s).slice(0, n);
  const rating = el => {
    const node = [...el.querySelectorAll('[role="img"][aria-label], .MW4etd')].find(x => /\bstars?\b/i.test(label(x)) || x.matches('.MW4etd'));
    return (label(node) || text(node)).match(/\b([0-5](?:[.,]\d)?)\b/)?.[1]?.replace(',', '.') || '';
  };
  const count = el => {
    const node = [...el.querySelectorAll('[aria-label]')].find(x => /^[\d,]+ reviews?\s*$/i.test(label(x).trim()));
    return label(node).match(/[\d,]+/)?.[0]?.replace(/,/g, '') || text(el.querySelector('.UY7F9')).replace(/[^\d]/g, '');
  };
  const safeLink = value => {
    try { const u = new URL(value, location.href); return u.protocol === 'https:' && /^(www\.google\.com|maps\.google\.com)$/.test(u.hostname) && u.pathname.startsWith('/maps') ? u.href : ''; } catch (_) { return ''; }
  };
  const feed = document.querySelector('[role="feed"]');
  const seen = new Set();
  const results = [];
  for (const a of (feed || document).querySelectorAll('a[href*="/maps/place/"]')) {
    const url = safeLink(a.href), name = bounded(label(a) || text(a), 180);
    if (!url || !name || seen.has(url)) continue;
    const card = a.closest('[role="article"]') || a.parentElement;
    const lines = text(card).split('\n').map(clean).filter(Boolean);
    const info = lines.find(x => x.includes('·') && !/^(Open|Closed|Closes|Opens)/i.test(x)) || '';
    const category = info.split('·')[0].trim();
    const address = info.split('·').slice(1).filter(x => /[\p{L}\d]/u.test(x)).join(' · ').trim();
    results.push({name, url, rating: rating(card), reviewCount: count(card), category: bounded(category, 100), address: bounded(address), summary: lines.filter(x => x !== name).slice(0, 4).join(' · ').slice(0, 400)});
    seen.add(url);
    if (results.length >= 15) break;
  }
  const h1 = [...document.querySelectorAll('h1')].find(x => text(x) && !/^Results$/i.test(text(x)));
  const main = h1?.closest('[role="main"]') || document;
  let place = null;
  if (h1) {
    const value = (selector, prefix) => {
      const el = main.querySelector(selector);
      return bounded((label(el) || text(el)).replace(prefix, ''));
    };
    const name = bounded(text(h1), 180);
    const categoryNode = main.querySelector('button[jsaction*="category"]');
    const lines = text(main).split('\n').map(clean).filter(Boolean);
    let index = lines.indexOf(name) + 1;
    while (index < lines.length && /^(?:[0-5](?:[.,]\d)?|\([\d,]+\))$/.test(lines[index])) index++;
    const category = text(categoryNode) || (lines[index] && !/^(Overview|Reviews|About|Directions)$/.test(lines[index]) ? lines[index].split('·')[0] : '');
    const hours = main.querySelector('[data-item-id="oh"]') || main.querySelector('[aria-label="Hours"]')?.closest('div')?.parentElement;
    const hoursLine = lines.find(x => /^(Open 24 hours|Open\s*·|Closed\s*·|Closes soon)/.test(x));
    const reviews = [], reviewIds = new Set();
    for (const node of main.querySelectorAll('div[data-review-id]')) {
      const id = node.getAttribute('data-review-id');
      const reviewText = text(node.querySelector('.wiI7pd'));
      if (!id || !reviewText || reviewIds.has(id)) continue;
      let reviewRoot = node;
      for (let i = 0; i < 3 && !reviewRoot.querySelector('.d4r55, button[aria-label^="Actions for "]') && reviewRoot.parentElement; i++) reviewRoot = reviewRoot.parentElement;
      const author = text(reviewRoot.querySelector('.d4r55, button[data-href*="/maps/contrib/"]')) || label(reviewRoot.querySelector('button[aria-label^="Actions for "]')).replace(/^Actions for /, '').replace(/'s review$/, '');
      reviews.push({author: bounded(author, 100), text: bounded(reviewText, 900), rating: Number(rating(node)) || 0});
      reviewIds.add(id);
      if (reviews.length >= 3) break;
    }
    const websiteNode = main.querySelector('a[data-item-id="authority"]');
    const website = websiteNode?.href || '';
    place = {name, category: bounded(category, 100), rating: rating(main), reviewCount: count(main), address: value('[data-item-id="address"]', /^Address:\s*/i), phone: value('[data-item-id^="phone:tel:"]', /^Phone:\s*/i), website: /^https?:\/\//i.test(website) ? website.slice(0, 500) : '', hours: bounded(hoursLine || text(hours).split('\n')[0]), url: safeLink(location.href), reviews};
  }
  let state = place ? 'place' : results.length ? 'results' : 'loading';
  if (location.hostname === 'consent.google.com' || /Before you continue to Google/i.test(body)) state = 'interaction';
  else if (location.pathname.startsWith('/sorry') || /unusual traffic|verify (?:that )?you(?:'re| are) human/i.test(body)) state = 'interaction';
  else if (!place && !results.length && /No results found|Google Maps can(?:not|'t) find|We could not find/i.test(body)) state = 'empty';
  return JSON.stringify({state, href: location.href, query: document.querySelector('#searchboxinput, input[aria-label="Search Google Maps"]')?.value || '', results, place});
})()
