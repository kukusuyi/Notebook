import { readFileSync, mkdtempSync, rmSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { tmpdir } from 'node:os'
import { resolve, join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const api = 'https://api.gitcode.com/api/v5/repos/xiaosusu/Questrace'
export function checksums(text) {
  const result = new Map()
  for (const line of text.trim().split('\n')) {
    const match = /^([a-f0-9]{64})  (Questrace-[A-Za-z0-9.-]+)$/.exec(line)
    if (!match || result.has(match[2])) throw Error('Invalid SHA256SUMS')
    result.set(match[2], match[1])
  }
  return result
}
const sha = bytes => createHash('sha256').update(bytes).digest('hex')
function gh(args) {
  const result = spawnSync('gh', args, { encoding: 'utf8' })
  if (result.status !== 0) throw Error('GitHub release operation failed; check workflow credentials and logs.')
  return result.stdout
}
async function request(path, { method = 'GET', body, query = {}, missing = false } = {}) {
  const url = new URL(api + path)
  url.search = new URLSearchParams({ ...query, access_token: process.env.GITCODE_TOKEN }).toString()
  let response
  try { response = await fetch(url, {method, headers: {'Content-Type': 'application/json'}, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(30000)}) }
  catch { throw Error('GitCode API connection failed') }
  const payload = await response.json().catch(() => null)
  if (missing && (response.status === 404 || (response.status === 400 && payload?.error_message === '未找到 release'))) return null
  if (!response.ok || !payload || payload.error_code) throw Error(`GitCode API failed (${response.status}); no credentials were logged`)
  return payload
}
async function verifyRemote(tag, name, expected) {
  // Download without a token: installed applications must be able to do the same.
  const url = `${api}/releases/${encodeURIComponent(tag)}/attach_files/${encodeURIComponent(name)}/download`
  const response = await fetch(url, {signal: AbortSignal.timeout(300000)})
  if (!response.ok) throw Error(`GitCode attachment unavailable: ${name}`)
  const hash = createHash('sha256')
  for await (const chunk of response.body) hash.update(chunk)
  if (hash.digest('hex') !== expected) throw Error(`GitCode checksum mismatch: ${name}`)
}
export async function publish(tag, directory, {apiRequest=request, githubCommand=gh, verifyAttachment=verifyRemote} = {}) {
  if (!/^v2\.\d+\.\d+$/.test(tag)) throw Error('A stable v2 release tag is required')
  if (!process.env.GITCODE_TOKEN) throw Error('Missing GITCODE_TOKEN secret')
  const notes = readFileSync(`.github/release-notes/${tag}.md`, 'utf8')
  const manifest = readFileSync(join(directory, 'SHA256SUMS'))
  const expected = checksums(manifest.toString())
  const version = tag.slice(1)
  const suffixes = ['windows-x64-Setup.exe','macos-x64.zip','macos-arm64.zip','linux-amd64.tar.gz','linux-arm64.tar.gz','android.apk']
  if (expected.size !== suffixes.length || suffixes.some(s => !expected.has(`Questrace-${version}-${s}`))) throw Error('Incomplete platform asset set')
  expected.set('SHA256SUMS', sha(manifest))
  for (const [name, hash] of expected) if (sha(readFileSync(join(directory,name))) !== hash) throw Error(`Local checksum mismatch: ${name}`)
  const github = JSON.parse(githubCommand(['release','view',tag,'--json','isDraft']))
  const remote = await apiRequest(`/releases/tags/${encodeURIComponent(tag)}`, {missing:true})
  if (!remote) await apiRequest('/releases', {method:'POST',body:{tag_name:tag,name:`Questrace ${version}`,body:notes,release_status:'pre'}})
  const published = remote?.release_status === 'latest' && !remote?.prerelease
  for (const [name, hash] of expected) {
    if (remote?.assets?.some(a => a.name === name)) {
      await verifyAttachment(tag,name,hash)
      continue
    }
    if (published) throw Error('Refusing to alter an incomplete published GitCode release')
    const upload = await apiRequest(`/releases/${encodeURIComponent(tag)}/upload_url`, {query:{file_name:name}})
    const target = new URL(upload.url)
    if (target.protocol !== 'https:' || target.username || target.password) throw Error('Invalid upload URL')
    let response
    try { response = await fetch(target,{method:'PUT',headers:upload.headers,body:readFileSync(join(directory,name)),signal:AbortSignal.timeout(300000)}) }
    catch { throw Error(`GitCode upload failed: ${name}`) }
    if (!response.ok) throw Error(`GitCode upload failed: ${name}`)
    await verifyAttachment(tag,name,hash)
  }
  // Verify the actual GitHub draft assets, not only the local build directory.
  const verifyDir = mkdtempSync(join(tmpdir(),'questrace-release-'))
  try {
    githubCommand(['release','download',tag,'--dir',verifyDir])
    for(const [name,hash] of expected) if(sha(readFileSync(join(verifyDir,name)))!==hash)throw Error(`GitHub checksum mismatch: ${name}`)
  } finally {rmSync(verifyDir,{recursive:true,force:true})}
  // Publishing is not transactional across hosts. Reruns verify immutable files
  // and finish the remaining host if the second publication is interrupted.
  if(!published)await apiRequest(`/releases/${encodeURIComponent(tag)}`,{method:'PATCH',body:{name:`Questrace ${version}`,body:notes,release_status:'latest'}})
  if(github.isDraft)githubCommand(['release','edit',tag,'--draft=false'])
  console.log(`Verified and published ${tag} on GitCode and GitHub.`)
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url))publish(process.argv[2],resolve(process.argv[3]||'release-assets')).catch(error=>{console.error(error.message);process.exitCode=1})
