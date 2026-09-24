const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {createRequire} = require('node:module');
const vm = require('node:vm');
const manifest = require('./package.json');

test('packaged main process loads using only shipped files', (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'questrace-package-'));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  // Stage the explicit shipping list without access to the source directory.
  for (const file of manifest.build.files) {
    fs.copyFileSync(path.join(__dirname, file), path.join(directory, file));
  }
  const entry = path.join(directory, manifest.main);
  const packagedRequire = createRequire(entry);
  let quit = false;
  const electron = {
    app: {
      // Exercise startup imports, then stop as a second instance would.
      requestSingleInstanceLock: () => false,
      quit: () => { quit = true; },
      on: () => {},
    },
  };
  vm.runInNewContext(fs.readFileSync(entry, 'utf8'), {
    require: (name) => name === 'electron' ? electron : packagedRequire(name),
    __dirname: directory,
  }, {filename: entry});
  assert.equal(quit, true, 'main process reached the single-instance check');
});
