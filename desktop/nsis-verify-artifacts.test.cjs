const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {crc32} = require('node:zlib');
const afterAllArtifactBuild = require('./build/nsis-verify-artifacts.cjs');
const {verifySetup} = afterAllArtifactBuild;

// Minimal NSIS executable: DOS header, PE header, header block with the NSIS
// signature at offset 1024 and its CRC in the last four bytes.
function fixture(flags = 1) {
  const buffer = Buffer.alloc(1088);
  buffer.write('MZ');
  buffer.writeUInt32LE(flags, 1024);
  Buffer.from('efbeadde4e756c6c736f6674496e7374', 'hex').copy(buffer, 1028);
  buffer.writeUInt32LE(64, 1048);
  buffer.writeUInt32LE(crc32(buffer.subarray(512, -4)), buffer.length - 4);
  return buffer;
}

async function withSetup(buffer, run) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'questrace-setup-'));
  try {
    const artifact = path.join(directory, 'Questrace-2.1.0-windows-x64-Setup.exe');
    fs.writeFileSync(artifact, buffer);
    return await run(artifact);
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
}

test('accepts a setup whose host does not expose an unpackable uninstaller', async () => {
  // Observed on the Windows runner: 7-Zip lists the application executables
  // only, so requiring an unpackable uninstaller would always fail there.
  const message = await withSetup(fixture(0), artifact =>
    verifySetup(artifact, async () => [
      {name: 'elevate.exe', buffer: Buffer.from('MZnot an NSIS executable')},
      {name: 'questrace-server.exe', buffer: Buffer.from('MZnot an NSIS executable')},
      {name: 'Questrace.exe', buffer: fixture(0)},
    ])
  );
  assert.match(message, /no unpackable uninstaller entry/);
  assert.match(message, /elevate\.exe, questrace-server\.exe, Questrace\.exe/);
});

test('verifies the bundled uninstaller when the host exposes it', async () => {
  const message = await withSetup(fixture(0), artifact =>
    verifySetup(artifact, async () => [
      {name: 'Uninstall Questrace.exe', buffer: fixture(1)},
      {name: 'Questrace.exe', buffer: fixture(0)},
    ])
  );
  assert.match(message, /embedded uninstaller integrity \(Uninstall Questrace\.exe\)/);
});

test('rejects a corrupted installer', async () => {
  const corrupted = fixture(0);
  corrupted[700] = 42;
  await assert.rejects(
    withSetup(corrupted, artifact => verifySetup(artifact, async () => [])),
    /CRC mismatch/,
  );
});

test('rejects duplicate uninstallers and a corrupted uninstaller', async () => {
  await assert.rejects(
    withSetup(fixture(0), artifact =>
      verifySetup(artifact, async () => [
        {name: 'a.exe', buffer: fixture(1)},
        {name: 'b.exe', buffer: fixture(1)},
      ])
    ),
    /Expected at most one bundled uninstaller, found 2: a\.exe, b\.exe/,
  );
  const corrupted = fixture(1);
  corrupted[700] = 42;
  await assert.rejects(
    withSetup(fixture(0), artifact =>
      verifySetup(artifact, async () => [{name: 'Uninstall.exe', buffer: corrupted}])
    ),
    /CRC mismatch/,
  );
});

test('ignores artifacts that are not Windows setups', async () => {
  assert.deepEqual(
    await afterAllArtifactBuild({
      artifactPaths: [
        '/tmp/Questrace-2.1.0-macos-arm64.zip',
        '/tmp/Questrace-2.1.0-linux-amd64.tar.gz',
        '/tmp/Questrace-2.1.0-windows-x64-Setup.exe.blockmap',
      ],
    }),
    [],
  );
});
