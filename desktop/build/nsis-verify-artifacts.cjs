const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {execFile} = require('node:child_process');
const {promisify} = require('node:util');
const {verify} = require('./nsis-integrity.cjs');
const execute = promisify(execFile);

module.exports = async result => {
  for (const artifact of result.artifactPaths) {
    if (!artifact.endsWith('-Setup.exe')) continue;
    verify(await fs.readFile(artifact));
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'questrace-nsis-'));
    try {
      const {getPath7za} = require('app-builder-lib/out/toolsets/7zip');
      await execute(await getPath7za(), ['e', artifact, `-o${directory}`, '-r', '*Uninstall*.exe', '-y']);
      const files = (await fs.readdir(directory)).filter(file => file.endsWith('.exe'));
      if (files.length !== 1) throw new Error('Expected exactly one bundled uninstaller');
      const metadata = verify(await fs.readFile(path.join(directory, files[0])));
      if (!(metadata.flags & 1)) throw new Error('Bundled executable is not an uninstaller');
      console.log('Verified final installer and embedded uninstaller integrity');
    } finally {
      await fs.rm(directory, {recursive: true, force: true});
    }
  }
  return [];
};
