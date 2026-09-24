const fs = require('node:fs/promises');
const {finalizeUninstaller} = require('./nsis-integrity.cjs');
let installed = false;

module.exports = async context => {
  if (process.platform !== 'darwin' || context.electronPlatformName !== 'win32' || installed) return;
  // On macOS electron-builder reconstructs the uninstaller from a PE stub and
  // an inner NSIS block. Its stored CRC can still refer to a different stub.
  // Finalize the generated file before electron-builder signs or embeds it.
  const {UninstallerReader} = require('app-builder-lib/out/targets/nsis/nsisUtil');
  const original = UninstallerReader.exec;
  UninstallerReader.exec = async function(installerPath, uninstallerPath) {
    // The temporary BUILD_UNINSTALLER container deliberately has no CRC;
    // UninstallerReader validates its structure and decompresses the payload.
    await original.call(this, installerPath, uninstallerPath);
    const buffer = await fs.readFile(uninstallerPath);
    finalizeUninstaller(buffer);
    await fs.writeFile(uninstallerPath, buffer);
    console.log('Verified reconstructed NSIS uninstaller CRC before signing');
  };
  installed = true;
};
