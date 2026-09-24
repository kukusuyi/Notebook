// User-visible strings and the bundled server executable name, kept in one
// place so the product name stays consistent and testable.
const productName = 'Questrace';

function serverBinaryName(platform) {
  return platform === 'win32' ? 'questrace-server.exe' : 'questrace-server';
}

exports.productName = productName;
exports.windowTitle = `题迹 ${productName}`;
exports.trayTooltip = `题迹 ${productName} 2.0`;
exports.trayOpenLabel = `打开 ${productName}`;
exports.serverBinaryName = serverBinaryName;
