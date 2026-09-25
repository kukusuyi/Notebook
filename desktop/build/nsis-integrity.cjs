const {crc32} = require('node:zlib');
const signature = Buffer.from('efbeadde4e756c6c736f6674496e7374', 'hex');

// NSIS scans 512-byte boundaries and checks bytes after the DOS header up to
// the stored CRC. Trailing Authenticode data is outside this range.
// https://github.com/kichik/nsis/blob/master/Source/exehead/fileform.c
function inspect(buffer) {
  if (buffer.length < 512 || buffer.toString('ascii', 0, 2) !== 'MZ') {
    throw new Error('Not a Windows NSIS executable');
  }
  for (let offset = 512; offset + 28 <= buffer.length; offset += 512) {
    if (!buffer.subarray(offset + 4, offset + 20).equals(signature)) continue;
    const flags = buffer.readUInt32LE(offset);
    if (flags & 2) throw new Error('NSIS CRC checking is disabled');
    const length = buffer.readUInt32LE(offset + 24);
    const end = offset + length;
    if (length < 32 || end > buffer.length) throw new Error('Truncated NSIS payload');
    return {flags, end, stored: buffer.readUInt32LE(end - 4),
      computed: crc32(buffer.subarray(512, end - 4))};
  }
  throw new Error('NSIS header not found');
}

function verify(buffer) {
  const result = inspect(buffer);
  if (result.stored !== result.computed) throw new Error('NSIS integrity check failed: CRC mismatch');
  return result;
}

// Report the unpacked executables that the NSIS header marks as uninstallers.
// Entry names differ between NSIS versions and build hosts, so the header flags
// decide; every candidate that claims to be an uninstaller must also match its
// stored CRC, and anything else is ignored.
function findUninstallers(candidates) {
  const found = [];
  for (const {name, buffer} of candidates) {
    let flags;
    try {
      flags = inspect(buffer).flags;
    } catch {
      continue;
    }
    if (!(flags & 1)) continue;
    verify(buffer);
    found.push(name);
  }
  return found;
}

// Only for a freshly reconstructed, unsigned uninstaller, before signing.
// Never call this on a downloaded installer or an installed user file.
function finalizeUninstaller(buffer) {
  const result = inspect(buffer);
  if (!(result.flags & 1) || result.end !== buffer.length) {
    throw new Error('Expected a freshly generated unsigned NSIS uninstaller');
  }
  buffer.writeUInt32LE(result.computed, result.end - 4);
  verify(buffer);
  return buffer;
}

module.exports = {inspect, verify, findUninstallers, finalizeUninstaller};
