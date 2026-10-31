"""Exercise production Maps cleanup in headless Chromium, without network access."""
from pathlib import Path
import shutil
import tempfile


def check_crops(page, script):
    import json
    from PIL import Image
    from io import BytesIO
    for height in [900, 2208]:
        page.set_viewport_size({'width': 1920, 'height': height + 480})
        page.set_content('''<style>
          body {margin:0;background:#9dd9ac}
          canvas {position:absolute;inset:0;width:100%;height:100%}
          .edge {position:fixed;width:160px;height:160px;background:red;z-index:4}
          .scene-footer-container {position:fixed;bottom:0;left:0;right:0;height:24px;background:blue;z-index:5}
          #pin {position:absolute;left:950px;top:500px;color:black}
        </style><canvas></canvas><div id="pin">Selected location</div>
        <div class="edge" style="top:20px;left:20px">Unknown control</div>
        <div class="edge" style="top:20px;right:20px">Unknown control</div>
        <div class="edge" style="bottom:40px;left:20px">Unknown control</div>
        <div class="edge" style="bottom:40px;right:20px">Unknown control</div>
        <div class="scene-footer-container">Map data ©2026 Google</div>''')
        crop = {'x': 240, 'y': 240, 'width': 1440, 'height': height}
        for footer in ['known', 'renamed', 'missing']:
            if footer == 'renamed':
                page.locator('.scene-footer-container').evaluate('(node) => node.className = "changed-footer"')
            elif footer == 'missing':
                page.locator('.changed-footer').evaluate('(node) => node.remove()')
            state = json.loads(page.evaluate(script))
            assert state['state'] == 'ready', 'footer must not affect readiness'
            assert 'attributionReady' not in state, 'attribution must not control capture'
            image = Image.open(BytesIO(page.screenshot(clip=crop))).convert('RGB')
            colors = {color for _, color in image.getcolors(maxcolors=image.width * image.height)}
            assert (255, 0, 0) not in colors, 'native edge control leaked into crop'
            assert (0, 0, 255) not in colors, 'native footer leaked into crop'
            assert image.size == (1440, height)
        page.locator('canvas').evaluate('(node) => node.remove()')
        assert json.loads(page.evaluate(script))['state'] == 'loading'


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
                check_crops(page, script)
                page.set_content('<img id="tile" style="width:256px;height:256px">')
                from urllib.parse import quote
                svg = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><!-- /maps/vt --><rect width="256" height="256" fill="green"/></svg>'
                # An offline image fixture carrying the same URL path marker.
                page.locator('#tile').evaluate('(node, src) => { node.src = src; return node.decode(); }', 'data:image/svg+xml,' + quote(svg))
                import json
                assert json.loads(page.evaluate(script))['state'] == 'ready', 'loaded raster map must be ready without a WebGL canvas'
                page.locator('#tile').evaluate('(node) => node.remove()')
                assert json.loads(page.evaluate(script))['state'] == 'loading'
            finally:
                browser.close()
        print('Production Maps checks passed: controls hidden/cropped, actual pixels of both aspect ratios exclude native controls and native footers regardless of footer layout, and external zoom remains usable.')


if __name__ == '__main__':
    main()
