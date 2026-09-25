const {test}=require('node:test');const assert=require('node:assert/strict');
const {isTrustedExternal}=require('./external-links.cjs');
test('allows official Qwen help and signup in system browser',()=>{for(const u of ['https://account.aliyun.com/register/qr_register.htm','https://bailian.console.aliyun.com/','https://help.aliyun.com/zh/model-studio/first-api-call-to-qwen'])assert.equal(isTrustedExternal(u),true)});
test('rejects arbitrary websites, credentials, ports and non-HTTPS schemes',()=>{for(const u of ['https://evil.test','https://help.aliyun.com.evil.test','https://user:password@help.aliyun.com','https://help.aliyun.com:8000','http://help.aliyun.com','file:///tmp/test','javascript:alert(1)'])assert.equal(isTrustedExternal(u),false)});

test('allows only Questrace release download links on GitHub',()=>{
 assert.equal(isTrustedExternal('https://github.com/kukusuyi/Questrace/releases/download/v2.1.0/Questrace-2.1.0-android.apk'),true);
 assert.equal(isTrustedExternal('https://github.com/elsewhere/repo/releases/latest'),false);
});
