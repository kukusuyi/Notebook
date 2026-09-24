const {test} = require('node:test');
const assert = require('node:assert/strict');
const {crc32} = require('node:zlib');
const {verify, finalizeUninstaller} = require('./build/nsis-integrity.cjs');
function fixture(flags = 1) {
  const buffer = Buffer.alloc(1088);
  buffer.write('MZ');
  buffer.writeUInt32LE(flags, 1024);
  Buffer.from('efbeadde4e756c6c736f6674496e7374', 'hex').copy(buffer, 1028);
  buffer.writeUInt32LE(64, 1048);
  buffer.writeUInt32LE(crc32(buffer.subarray(512, -4)), buffer.length - 4);
  return buffer;
}
test('checks both installer and uninstaller integrity', () => {
  verify(fixture(0)); verify(fixture(1));
});
test('detects changed PE stub and finalizes only generated uninstallers', () => {
  const buffer = fixture(); buffer[700] = 42;
  assert.throws(() => verify(buffer), /CRC mismatch/);
  const original = Buffer.from(buffer);
  finalizeUninstaller(buffer); verify(buffer);
  assert.deepEqual(buffer.subarray(0, -4), original.subarray(0, -4));
});
test('rejects disabled CRC, truncation and incorrect executable types', () => {
  assert.throws(() => verify(fixture(3)), /disabled/);
  assert.throws(() => verify(fixture().subarray(0, -1)), /Truncated/);
  assert.throws(() => finalizeUninstaller(fixture(0)), /unsigned NSIS uninstaller/);
  assert.throws(() => finalizeUninstaller(Buffer.concat([fixture(), Buffer.alloc(8)])), /unsigned NSIS uninstaller/);
});
test('verification allows trailing signing data outside the CRC range', () => {
  verify(Buffer.concat([fixture(), Buffer.alloc(64, 0x12)]));
});
test('finalization is idempotent and later corruption remains detectable', () => {
  const buffer = fixture(); const original = Buffer.from(buffer);
  finalizeUninstaller(buffer); assert.deepEqual(buffer, original);
  buffer[1052] ^= 1;
  assert.throws(() => verify(buffer), /CRC mismatch/);
});
