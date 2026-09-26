import {spawnSync} from 'node:child_process'
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs'
import {treeFingerprint} from './verification-state.mjs'
import {resolve} from 'node:path'
const root=resolve(import.meta.dirname,'..')
function git(args){const p=spawnSync('git',args,{cwd:root,encoding:'utf8'});if(p.status!==0)throw Error('Cannot inspect Git state');return p.stdout.trim()}
const head=git(['rev-parse','HEAD'])
const tree=()=>treeFingerprint(root)
const before=tree(),results=[]
function check(name,command,args,cwd='.'){
 console.log(`\n${name}`)
 const result=spawnSync(command,args,{cwd:resolve(root,cwd),stdio:'inherit',env:process.env})
 results.push({name,passed:result.status===0})
}
check('versions','node',['scripts/check-version.mjs'])
check('themes','python3',['scripts/generate-themes.py','--check'])
check('release scripts','node',['--test','scripts/release-tools.test.mjs'])
check('backend','go',['test','./...'],'backend')
check('frontend tests','npm',['test'],'frontend')
check('frontend build','npm',['run','build'],'frontend')
check('desktop tests','node',['--test'],'desktop')
check('embedded build','node',['scripts/build.mjs'])
const version=JSON.parse(readFileSync(resolve(root,'desktop/package.json'))).version
const os={darwin:'darwin',win32:'windows',linux:'linux'}[process.platform]
const arch=process.arch==='arm64'?'arm64':'amd64'
check('embedded smoke','python3',['scripts/smoke.py',`dist/questrace-${version}-${os}-${arch}/questrace-server${os==='windows'?'.exe':''}`])
check('flutter analyze','flutter',['analyze'],'mobile/flutter_app')
check('flutter tests','flutter',['test'],'mobile/flutter_app')
check('android build','flutter',['build','apk','--release','--dart-define=APP_FLAVOR=production'],'mobile/flutter_app')
check('iOS simulator build','node',['scripts/build-ios-simulator.mjs'])
let manual={}
try{manual=JSON.parse(readFileSync(resolve(root,'dist/local-network-verification.json'),'utf8'))}catch{}
const scenarios=['macos_phone','windows_phone','wifi_reconnect','permission_denied','multicast_unavailable','device_isolation']
results.push({name:'physical LAN verification',passed:manual.commit===head&&manual.tree===before&&scenarios.every(key=>manual[key]?.passed===true&&typeof manual[key]?.evidence==='string'&&manual[key].evidence.trim().length>0)})
const passed=results.every(r=>r.passed)&&before===tree()&&head===git(['rev-parse','HEAD'])
mkdirSync(resolve(root,'dist'),{recursive:true})
writeFileSync(resolve(root,'dist/local-verification.json'),JSON.stringify({commit:head,tree:before,at:new Date().toISOString(),passed,results},null,2))
for(const result of results)console.log(`${result.passed?'PASS':'FAIL'} ${result.name}`)
if(!passed)process.exitCode=1
