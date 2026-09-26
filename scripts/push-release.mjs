import {treeFingerprint} from './verification-state.mjs'
import {spawnSync} from 'node:child_process'
import {readFileSync} from 'node:fs'
import {resolve} from 'node:path'
const root=resolve(import.meta.dirname,'..')
function git(args){const r=spawnSync('git',args,{cwd:root,encoding:'utf8',env:{...process.env,GIT_TERMINAL_PROMPT:'0'}});if(r.status!==0)throw Error(`Git operation failed: ${args[0]}`);return r.stdout.trim()}
try{
 const head=git(['rev-parse','HEAD'])
 if(git(['branch','--show-current'])!=='master-v2.0')throw Error('Release must use master-v2.0')
 if(git(['status','--porcelain']))throw Error('Commit and verify the final clean tree before pushing; preserve unrelated work separately')
 const report=JSON.parse(readFileSync(resolve(root,'dist/local-verification.json'),'utf8'))
 if(report.commit!==head||report.tree!==treeFingerprint(root)||!report.passed||Date.now()-Date.parse(report.at)>86400000)throw Error('Missing, failed, or stale local verification for this commit')
 const version=JSON.parse(readFileSync(resolve(root,'desktop/package.json'))).version
 const tag=`v${version}`
 const targets={gitcode:'https://gitcode.com/xiaosusu/Questrace.git',origin:'https://github.com/kukusuyi/Questrace.git'}
 for(const [remote,url]of Object.entries(targets))if(git(['remote','get-url','--push',remote])!==url)throw Error(`Unexpected ${remote} remote`)
 let existing='';try{existing=git(['rev-parse',`${tag}^{commit}`])}catch{}
 if(existing&&existing!==head)throw Error('Release tag belongs to another commit')
 if(!existing)git(['tag',tag,head])
 // GitCode receives the branch and tag before GitHub can trigger Actions.
 git(['push','--atomic','gitcode',`HEAD:refs/heads/master-v2.0`,`refs/tags/${tag}`])
 const gc=git(['ls-remote','gitcode','refs/heads/master-v2.0']).split(/\s/)[0]
 if(gc!==head)throw Error('GitCode branch verification failed')
 git(['push','--atomic','origin',`HEAD:refs/heads/master-v2.0`,`refs/tags/${tag}`])
 const gh=git(['ls-remote','origin','refs/heads/master-v2.0']).split(/\s/)[0]
 if(gh!==head)throw Error('GitHub branch verification failed')
 console.log(`Both remotes point to ${head}; ${tag} build dispatched.`)
}catch(e){console.error(e.message);process.exitCode=1}
