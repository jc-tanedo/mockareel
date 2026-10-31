"""Exercise production Maps cleanup in headless Chromium, without network access."""
from pathlib import Path
import shutil
import tempfile


def main():
    chromium = shutil.which('chromium') or shutil.which('google-chrome')
    if not chromium:
        raise SystemExit('Install Chromium to run this optional DOM check.')
    from playwright.sync_api import sync_playwright
    script = (Path(__file__).resolve().parent.parent / 'assets/maps_header.js').read_text()
    with tempfile.TemporaryDirectory(prefix='mockareel-map-dom-') as temporary:
        root = Path(temporary)
        fixture = root / 'fixture.html'
        fixture.write_text('''<!doctype html><html><head><meta charset="utf-8"></head><body>
          <div id="omnibox-container">Search</div>
          <canvas style="width:1000px;height:600px"></canvas>
          <div id="pin" role="button" aria-label="Fixture Cafe">Fixture Cafe</div>
          <div id="minimap">Satellite tile</div>
          <div class="widget-zoom"><button aria-label="Zoom in">+</button><button aria-label="Zoom out">-</button></div>
          <button id="location" aria-label="Show Your Location">Location</button>
          <button id="pegman" aria-label="Drag Pegman onto the map to open Street View">Pegman</button>
          <button id="layers" aria-label="Layers">Layers</button>
          <div class="scene-footer-container"><a id="branding">Google Maps</a><span id="copyright">Map data ©2026 Google</span><a id="terms">Terms</a></div>
          <script>
          let zooms = 0;
          document.querySelector('[aria-label="Zoom in"]').addEventListener('click', () => zooms++);
          const initial = SCRIPT;
          const observer = window.__mockareelHeaderObserver;
          SCRIPT;
          setTimeout(() => {
            const late = document.createElement('div');
            late.id = 'late'; late.setAttribute('role', 'button');
            late.setAttribute('aria-label', 'Street View');
            document.body.appendChild(late);
            const changed = document.createElement('button');
            changed.id = 'changed'; document.body.appendChild(changed);
            changed.setAttribute('aria-label', 'Full screen');
            setTimeout(() => {
              try {
                const visible = id => getComputedStyle(document.getElementById(id)).visibility !== 'hidden';
                for (const id of ['omnibox-container','minimap','location','pegman','layers','late','changed']) {
                  if (visible(id)) throw Error(id + ' still visible');
                }
                for (const id of ['pin','branding','copyright','terms']) {
                  if (!visible(id)) throw Error(id + ' was hidden');
                }
                document.querySelector('[aria-label="Zoom in"]').click();
                if (zooms !== 1) throw Error('external zoom is broken');
                if (JSON.parse(initial).state !== 'ready') throw Error('map no longer ready');
                if (observer !== window.__mockareelHeaderObserver) throw Error('duplicate observer');
                document.body.setAttribute('data-test-result', 'passed');
              } catch (error) { document.body.setAttribute('data-test-result', error.message); }
            }, 60);
          }, 60);
          </script></body></html>'''.replace('SCRIPT', script))
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path=chromium, args=['--no-sandbox', '--disable-dev-shm-usage'])
            try:
                page = browser.new_page()
                page.set_content(fixture.read_text())
                page.wait_for_selector('body[data-test-result]', state='attached', timeout=5000)
                result = page.locator('body').get_attribute('data-test-result')
                if result != 'passed':
                    raise SystemExit('Map DOM check failed: ' + str(result))
            finally:
                browser.close()
        print('Production Maps cleanup passed: initial/dynamic controls hidden; pins, attribution and external zoom retained; observer is idempotent.')


if __name__ == '__main__':
    main()
