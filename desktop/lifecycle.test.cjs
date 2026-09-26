const {test} = require('node:test');
const assert = require('node:assert/strict');
const {EventEmitter} = require('node:events');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, 'main.cjs'), 'utf8');

async function launch({health} = {}) {
  const app = new EventEmitter();
  const child = new EventEmitter();
  const lines = new EventEmitter();
  const timers = new Map();
  const intervals = new Map();
  const windows = [];
  const errors = [];
  let ended = 0, exited = false, trayDestroyed = false;
  const signals = [];
  child.stdin = new EventEmitter();
  child.stdin.end = () => { ended++; };
  child.stderr = new EventEmitter();
  child.kill = signal => { signals.push(signal); return true; };
  app.requestSingleInstanceLock = () => true;
  app.getPath = () => '/test-app-data';
  app.whenReady = () => Promise.resolve();
  app.quit = () => {
    let prevented = false;
    app.emit('before-quit', {preventDefault() { prevented = true; }});
    if (!prevented) { app.emit('will-quit'); exited = true; }
  };
  class BrowserWindow extends EventEmitter {
    constructor() {
      super(); windows.push(this);
      this.webContents = new EventEmitter();
      this.webContents.setWindowOpenHandler = () => {};
    }
    hide() { this.hidden = true; }
    loadURL() { return Promise.resolve(); }
  }
  class Tray extends EventEmitter {
    setToolTip() {}
    setContextMenu() {}
    destroy() { trayDestroyed = true; }
  }
  const electron = {app, BrowserWindow, Tray, Menu: {buildFromTemplate: x => x},
    nativeImage: {createFromDataURL() {}}, dialog: {showErrorBox: (...args) => errors.push(args)}};
  vm.runInNewContext(source, {
    __dirname, process: {platform: 'win32'},
    require(name) {
      if (name === 'electron') return electron;
      if (name === 'node:child_process') return {spawn: () => child};
      if (name === 'node:readline') return {createInterface: () => lines};
      if (name === './data-dir.cjs') return {resolveDataDir: () => '/test-data'};
      return require(name);
    },
    fetch: health || (() => Promise.resolve({ok: true})),
    setTimeout(fn, delay) { const token = {}; timers.set(token, {fn, delay}); return token; },
    clearTimeout(token) { timers.delete(token); },
    setInterval(fn,delay){const token={};intervals.set(token,{fn,delay});return token},
    clearInterval(token){intervals.delete(token)},
    URL,
  });
  await new Promise(setImmediate);
  return {app, child, timers, intervals, windows, signals, errors,
    state: () => ({ended, exited, trayDestroyed}),
    async ready() {
      lines.emit('line', JSON.stringify({event: 'ready', url: 'http://127.0.0.1:8080', urls: []}));
      await new Promise(setImmediate);
    },
  };
}

test('Windows close stops backend and exits after it finishes', async () => {
  const run = await launch();
  await run.ready();
  run.windows[0].emit('close', {preventDefault() {}});
  assert.equal(run.windows[0].hidden, undefined);
  assert.deepEqual(run.state(), {ended: 1, exited: false, trayDestroyed: false});
  run.child.emit('exit', 0);
  assert.deepEqual(run.state(), {ended: 1, exited: true, trayDestroyed: true});
  assert.equal(run.timers.size, 0);
  assert.equal(run.intervals.size,0);
  assert.equal(run.errors.length, 0);
});

test('repeated quit requests preserve one shutdown deadline and force a stalled backend to exit', async () => {
  const run = await launch();
  await run.ready();
  run.app.quit();
  run.app.quit();
  assert.equal(run.state().ended, 1);
  assert.equal(run.timers.size, 1);
  const deadline = [...run.timers.values()][0];
  assert.equal(deadline.delay, 11000);
  run.child.stdin.emit('error', Object.assign(new Error('closed pipe'), {code: 'EPIPE'}));
  deadline.fn();
  assert.deepEqual(run.signals, ['SIGKILL']);
  run.child.emit('exit', null, 'SIGKILL');
  assert.equal(run.state().exited, true);
});

test('quitting during startup ignores a late backend ready event', async () => {
  const run = await launch();
  run.app.quit();
  await run.ready();
  assert.equal(run.windows.length, 0);
  run.child.emit('exit', 0);
  assert.equal(run.state().exited, true);
});

test('quitting during the health check does not reopen the window', async () => {
  let resolveHealth;
  const run = await launch({health: () => new Promise(resolve => { resolveHealth = resolve; })});
  await run.ready();
  run.app.quit();
  resolveHealth({ok: true});
  await new Promise(setImmediate);
  assert.equal(run.windows.length, 0);
  run.child.emit('exit', 0);
  assert.equal(run.state().exited, true);
});
