import {spawnSync} from 'node:child_process'
import {createHash} from 'node:crypto'
import {readFileSync} from 'node:fs'
import {join} from 'node:path'
export function gitOutput(root,args){const result=spawnSync('git',args,{cwd:root,encoding:'utf8'});if(result.status!==0)throw Error('Cannot inspect Git state');return result.stdout}
export function treeFingerprint(root){
 const hash=createHash('sha256').update(gitOutput(root,['diff','HEAD','--binary']))
 const files=gitOutput(root,['ls-files','--others','--exclude-standard','-z']).split('\0').filter(Boolean).sort()
 for(const file of files)hash.update(file).update('\0').update(readFileSync(join(root,file))).update('\0')
 return hash.digest('hex')
}
