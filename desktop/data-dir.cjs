// Questrace stores data in its own application-data directory. An installation
// that only has the pre-rename Notebook directory keeps using it in place, so an
// upgrade never copies or moves user data. When both directories exist the choice
// would be arbitrary, so startup stops instead of silently opening wrong data.
const path = require('node:path');
const fs = require('node:fs');

const currentName = 'Questrace';
const legacyName = 'Notebook';
const environmentVariables = ['QUESTRACE_DATA_DIR', 'NOTEBOOK_DATA_DIR'];

function resolveDataDir({ env = process.env, appDataDir, exists = fs.existsSync } = {}) {
  for (const name of environmentVariables) {
    if (env[name]) return env[name];
  }
  const current = path.join(appDataDir, currentName);
  const legacy = path.join(appDataDir, legacyName);
  const hasCurrent = exists(current);
  const hasLegacy = exists(legacy);
  if (hasCurrent && hasLegacy) {
    throw new Error(
      `同时存在数据目录 ${current} 与 ${legacy}，请保留其中一个，或设置 ${environmentVariables[0]} 指定要使用的目录。`,
    );
  }
  return hasLegacy ? legacy : current;
}

exports.resolveDataDir = resolveDataDir;
