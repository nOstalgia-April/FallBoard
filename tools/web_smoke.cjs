// Run after exporting Web. Requires Playwright (CI installs a pinned version).
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../builds/web');
const dist = path.resolve(__dirname, '../dist');
const types = { '.html':'text/html', '.js':'application/javascript', '.wasm':'application/wasm', '.png':'image/png', '.pck':'application/octet-stream' };
const server = http.createServer((request, response) => {
  const route = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const filename = path.resolve(root, '.' + (route === '/' ? '/index.html' : route));
  if (!filename.startsWith(root + path.sep) || !fs.existsSync(filename)) {
    response.writeHead(404); response.end(); return;
  }
  response.writeHead(200, { 'Content-Type':types[path.extname(filename)] || 'application/octet-stream' });
  fs.createReadStream(filename).pipe(response);
});

(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless:true, args:['--enable-unsafe-swiftshader'] });
  try {
    const page = await browser.newPage({ viewport:{width:1440,height:900}, deviceScaleFactor:1 });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      console.log(message.type() + ': ' + message.text());
      if (message.type()==='error' && /SCRIPT ERROR|Parse Error|Failed loading resource/i.test(message.text())) errors.push(message.text());
    });
    await page.goto(`http://127.0.0.1:${server.address().port}/`, { waitUntil:'networkidle' });
    await page.locator('#status').waitFor({ state:'hidden', timeout:60000 });
    await page.waitForTimeout(1000);
    const initial = await page.screenshot({ path:path.join(dist,'FallBoard-web.png') });
    await page.mouse.click(490,500);
    await page.mouse.move(490,320);
    await page.waitForTimeout(100);
    await page.screenshot({ path:path.join(dist,'FallBoard-web-preview.png') });
    await page.mouse.click(490,320);
    await page.waitForTimeout(700);
    await page.mouse.click(850,500);
    await page.mouse.click(850,320);
    await page.waitForTimeout(700);
    const victory = await page.screenshot({ path:path.join(dist,'FallBoard-web-victory.png') });
    assert(!initial.equals(victory), 'Canvas must react to real mouse input');
    assert.deepEqual(errors, [], 'Web build must not emit JavaScript or Godot script errors');
    console.log('WEB SMOKE PASSED: loaded WASM, rendered, accepted real mouse input, captured victory flow.');
  } finally {
    await browser.close();
    server.close();
  }
})().catch(error => { console.error(error); server.close(); process.exitCode=1; });
