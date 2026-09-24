const {test}=require('node:test');const assert=require('node:assert/strict');
const path=require('node:path');
const {resolveDataDir}=require('./data-dir.cjs');
const appData='/tmp/app-data';
const existsWith=(...dirs)=>(target)=>dirs.includes(target);
test('prefers the Questrace environment variable over the legacy alias',()=>{
 assert.equal(resolveDataDir({env:{QUESTRACE_DATA_DIR:'/current',NOTEBOOK_DATA_DIR:'/legacy'},appDataDir:appData,exists:()=>false}),'/current');
 assert.equal(resolveDataDir({env:{NOTEBOOK_DATA_DIR:'/legacy'},appDataDir:appData,exists:()=>false}),'/legacy');
});
test('uses the Questrace directory for a fresh installation',()=>{
 assert.equal(resolveDataDir({env:{},appDataDir:appData,exists:()=>false}),path.join(appData,'Questrace'));
});
test('keeps using a pre-rename Notebook directory in place',()=>{
 const legacy=path.join(appData,'Notebook');
 assert.equal(resolveDataDir({env:{},appDataDir:appData,exists:existsWith(legacy)}),legacy);
});
test('stops when both the Questrace and the Notebook directory exist',()=>{
 const current=path.join(appData,'Questrace'),legacy=path.join(appData,'Notebook');
 assert.throws(()=>resolveDataDir({env:{},appDataDir:appData,exists:existsWith(current,legacy)}),/QUESTRACE_DATA_DIR/);
});
