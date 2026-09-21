import { spawnSync } from 'node:child_process'
import { cpSync, mkdirSync, rmSync, writeFileSync, chmodSync } from 'node:fs'
import { dirname,resolve } from 'node:path'
import {fileURLToPath} from 'node:url'
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..')
const target=process.env.GOOS||({win32:'windows',darwin:'darwin',linux:'linux'}[process.platform])
const arch=process.env.GOARCH||(process.arch==='arm64'?'arm64':'amd64')
function run(cmd,args,cwd,env={}){const p=spawnSync(cmd,args,{cwd:resolve(root,cwd),stdio:'inherit',env:{...process.env,...env},shell:process.platform==='win32'});if(p.error)throw p.error;if(p.status!==0)process.exit(p.status||1)}
run('npm',['ci'],'frontend');run('npm',['run','build'],'frontend')
rmSync(resolve(root,'backend/web'),{recursive:true,force:true});mkdirSync(resolve(root,'backend/web'),{recursive:true});writeFileSync(resolve(root,'backend/web/.gitkeep'),'');cpSync(resolve(root,'frontend/dist'),resolve(root,'backend/web'),{recursive:true})
const name='notebook-server'+(target==='windows'?'.exe':'')
const output=resolve(root,'dist',`notebook-2.0.0-${target}-${arch}`);mkdirSync(output,{recursive:true})
run(process.env.GO_BINARY||'go',['build','-trimpath','-ldflags=-s -w','-o',resolve(output,name),'./cmd/api'],'backend',{GOOS:target,GOARCH:arch,CGO_ENABLED:'0'})
if(target==='linux'){writeFileSync(resolve(output,'start.sh'),'#!/bin/sh\nset -eu\nHERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec "$HERE/notebook-server" "$@"\n');chmodSync(resolve(output,'start.sh'),0o755)}
if(target==='darwin'||target==='windows'){mkdirSync(resolve(root,'desktop/resources'),{recursive:true});cpSync(resolve(output,name),resolve(root,'desktop/resources',name))}
console.log(`Built ${output}`)
