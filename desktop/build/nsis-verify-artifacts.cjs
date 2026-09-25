const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {execFile} = require('node:child_process');
const {promisify} = require('node:util');
const {findUninstallers, verify} = require('./nsis-integrity.cjs');
const execute = promisify(execFile);

// Unpack every executable from the setup instead of guessing the uninstaller
// file name. Which entries 7-Zip exposes depends on the build host: Windows
// setups only list the application executables.
async function unpackExecutables(artifact) {
  const {getPath7za} = require('app-builder-lib/out/toolsets/7zip');
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'questrace-nsis-'));
  try {
    await execute(await getPath7za(), ['e', artifact, `-o${directory}`, '-r', '*.exe', '-y']);
    const files = (await fs.readdir(directory)).filter(file => file.endsWith('.exe'));
    const candidates = [];
    for (const file of files) {
      candidates.push({name: file, buffer: await fs.readFile(path.join(directory, file))});
    }
    return candidates;
  } finally {
    await fs.rm(directory, {recursive: true, force: true});
  }
}

// Verify one built setup: the installer itself, plus the bundled uninstaller
// whenever the host exposes it. Candidates that claim to be uninstallers are
// always integrity checked, and two of them are always an error.
async function verifySetup(artifact, unpack = unpackExecutables) {
  verify(await fs.readFile(artifact));
  const candidates = await unpack(artifact);
  const uninstallers = findUninstallers(candidates);
  if (uninstallers.length > 1) {
    throw new Error(
      `Expected at most one bundled uninstaller, found ${uninstallers.length}: ${uninstallers.join(', ')}`
    );
  }
  const unpacked = candidates.map(candidate => candidate.name).join(', ') || 'none';
  return uninstallers.length === 1
    ? `Verified final installer and embedded uninstaller integrity (${uninstallers[0]})`
    : `Verified final installer integrity; this host exposes no unpackable uninstaller entry (unpacked: ${unpacked})`;
}

async function afterAllArtifactBuild(result, unpack) {
  for (const artifact of result.artifactPaths) {
    if (!artifact.endsWith('-Setup.exe')) continue;
    console.log(await verifySetup(artifact, unpack));
  }
  return [];
}

module.exports = result => afterAllArtifactBuild(result);
module.exports.verifySetup = verifySetup;
