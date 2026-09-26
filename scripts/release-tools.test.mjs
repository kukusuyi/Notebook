import {test} from 'node:test'
import assert from 'node:assert/strict'
import {checksums} from './publish-mirrors.mjs'
test('manifest rejects traversal, duplicate or malformed entries',()=>{
 const hash='a'.repeat(64)
 assert.equal(checksums(`${hash}  Questrace-2.1.1-android.apk`).size,1)
 for(const text of [`${hash}  ../key`,`${hash}  Questrace-a\n${hash}  Questrace-a`,'oops'])assert.throws(()=>checksums(text))
})

import {publish} from './publish-mirrors.mjs'
import {mkdtempSync,writeFileSync,readFileSync,rmSync} from 'node:fs'
import {tmpdir} from 'node:os'
import {join} from 'node:path'
import {createHash} from 'node:crypto'
test('mirror checksum failure prevents publication; retry verifies before promoting',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'questrace-mirror-test-'))
 const suffixes=['windows-x64-Setup.exe','macos-x64.zip','macos-arm64.zip','linux-amd64.tar.gz','linux-arm64.tar.gz','android.apk']
 const names=suffixes.map(s=>`Questrace-2.1.1-${s}`)
 for(const name of names)writeFileSync(join(dir,name),'test artifact')
 const hash=createHash('sha256').update('test artifact').digest('hex')
 writeFileSync(join(dir,'SHA256SUMS'),names.map(n=>`${hash}  ${n}`).join('\n'))
 names.push('SHA256SUMS')
 const old=process.env.GITCODE_TOKEN;process.env.GITCODE_TOKEN='test-only'
 let published=false,verified=0;const actions=[]
 const deps={
  apiRequest:async(path,options)=>{if(options?.method==='PATCH'){actions.push('gitcode publish');published=true;return {}};return{release_status:published?'latest':'pre',assets:names.map(name=>({name}))}},
  githubCommand:args=>{if(args[0]==='release'&&args[1]==='view')return JSON.stringify({isDraft:!published});if(args[1]==='download'){for(const name of names)writeFileSync(join(args.at(-1),name),readFileSync(join(dir,name)));return ''};actions.push('github publish');return ''},
  verifyAttachment:async()=>{verified++;throw Error('checksum mismatch')},
 }
 try{
  await assert.rejects(()=>publish('v2.1.1',dir,deps),/checksum mismatch/)
  assert.deepEqual(actions,[])
  deps.verifyAttachment=async()=>{verified++}
  await publish('v2.1.1',dir,deps)
  assert.deepEqual(actions,['gitcode publish','github publish'])
  assert.equal(verified,8)
  actions.length=0
  await publish('v2.1.1',dir,deps)
  assert.deepEqual(actions,[])
 }finally{if(old===undefined)delete process.env.GITCODE_TOKEN;else process.env.GITCODE_TOKEN=old;rmSync(dir,{recursive:true,force:true})}
})
