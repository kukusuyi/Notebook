// Flutter 3.44's multi-arch lipo check is incompatible with Xcode 27's lipo.
// A local simulator only needs the host architecture; no SDK files are modified.
import {spawnSync} from 'node:child_process'
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs'
import {tmpdir} from 'node:os'
import {join,resolve} from 'node:path'
if(process.platform!=='darwin')throw Error('iOS simulator builds require macOS')
const directory=mkdtempSync(join(tmpdir(),'questrace-simulator-'))
try{
 const config=join(directory,'host.xcconfig')
 writeFileSync(config,`ARCHS = ${process.arch==='arm64'?'arm64':'x86_64'}\nONLY_ACTIVE_ARCH = YES\n`)
 const result=spawnSync('flutter',['build','ios','--simulator','--debug','--dart-define=APP_FLAVOR=production'],{cwd:resolve(import.meta.dirname,'../mobile/flutter_app'),stdio:'inherit',env:{...process.env,XCODE_XCCONFIG_FILE:config}})
 process.exitCode=result.status??1
}finally{rmSync(directory,{recursive:true,force:true})}
