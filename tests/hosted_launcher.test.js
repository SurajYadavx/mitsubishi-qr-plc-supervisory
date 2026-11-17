const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const html = fs.readFileSync('dist/hosted/index.html', 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
assert.equal(scripts.length, 1, 'launcher must contain one inline script and no external script dependency');

function makeHarness(value = '') {
  const nodes = new Map();
  for (const id of ['gateway', 'status', 'open']) {
    nodes.set(id, { value: id === 'gateway' ? value : '', textContent: '', style: {}, handlers: {}, addEventListener(type, fn) { this.handlers[type] = fn; } });
  }
  const saved = new Map();
  let destination = null;
  const document = { getElementById(id) { assert.ok(nodes.has(id), `unexpected DOM node ${id}`); return nodes.get(id); } };
  const localStorage = { getItem(k) { return saved.get(k) || null; }, setItem(k, v) { saved.set(k, String(v)); } };
  const window = { location: { assign(url) { destination = url; } } };
  vm.runInNewContext(scripts[0], { document, localStorage, window, URL, String, Error });
  // The real page restores a saved value on load; simulate the operator typing afterward.
  nodes.get('gateway').value = value;
  return { nodes, saved, get destination() { return destination; }, click() { nodes.get('open').handlers.click(); } };
}

{
  const h = makeHarness('192.168.3.238');
  h.click();
  assert.equal(h.destination, 'http://192.168.3.238/');
  assert.equal(h.saved.get('qr_plc_esp32_gateway_url'), 'http://192.168.3.238');
}
{
  const h = makeHarness('10.10.1.22');
  h.click();
  assert.equal(h.destination, 'http://10.10.1.22/');
}
{
  const h = makeHarness('https://192.168.3.238');
  h.click();
  assert.equal(h.destination, null);
  assert.match(h.nodes.get('status').textContent, /HTTP/);
}
{
  const h = makeHarness('https://example.com');
  h.click();
  assert.equal(h.destination, null);
  assert.match(h.nodes.get('status').textContent, /HTTP/);
}
{
  const h = makeHarness('8.8.8.8');
  h.click();
  assert.equal(h.destination, null);
  assert.match(h.nodes.get('status').textContent, /private LAN/);
}
{
  const h = makeHarness('http://user:pass@192.168.3.1');
  h.click();
  assert.equal(h.destination, null);
  assert.match(h.nodes.get('status').textContent, /credentials/);
}
{
  const h = makeHarness('');
  h.click();
  assert.equal(h.destination, null);
  assert.match(h.nodes.get('status').textContent, /Enter the ESP32 IP/);
}

console.log('[Hosted launcher checks] 7 PASS, 0 FAIL');
