const {test}=require('node:test');const assert=require('node:assert/strict');
const branding=require('./branding.cjs');
const source=require('node:fs').readFileSync(require('node:path').join(__dirname,'main.cjs'),'utf8');
test('uses the Questrace product name in window and tray text',()=>{
 assert.equal(branding.productName,'Questrace');
 assert.equal(branding.windowTitle,'题迹 Questrace');
 assert.equal(branding.trayTooltip,'题迹 Questrace 2.0');
 assert.equal(branding.trayOpenLabel,'打开 Questrace');
 assert.ok(source.includes('branding.windowTitle'));
 assert.ok(source.includes('branding.trayTooltip'));
 assert.ok(source.includes('branding.trayOpenLabel'));
});
test('launches the renamed server binary',()=>{
 assert.equal(branding.serverBinaryName('win32'),'questrace-server.exe');
 assert.equal(branding.serverBinaryName('darwin'),'questrace-server');
 assert.ok(source.includes('branding.serverBinaryName'));
 assert.ok(!source.includes('notebook-server'));
});
test('the window and tray text never show the pre-rename product name',()=>{
 for(const value of [branding.windowTitle,branding.trayTooltip,branding.trayOpenLabel])assert.ok(!/Notebook/.test(value),value);
});
