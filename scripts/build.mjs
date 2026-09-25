import { spawnSync } from 'node:child_process'
import {
  chmodSync,
  cpSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const version = JSON.parse(
  readFileSync(resolve(root, 'desktop/package.json'), 'utf8'),
).version

if (
  process.env.RELEASE_VERSION &&
  process.env.RELEASE_VERSION !== version
) {
  throw new Error(
    `Release version ${process.env.RELEASE_VERSION} does not match desktop/package.json ${version}`,
  )
}

const target =
  process.env.GOOS ??
  { win32: 'windows', darwin: 'darwin', linux: 'linux' }[process.platform]
const arch =
  process.env.GOARCH ?? (process.arch === 'arm64' ? 'arm64' : 'amd64')
const goBinary = process.env.GO_BINARY ?? 'go'

function run(command, args, cwd, env = {}) {
  const npmNeedsWindowsShell = process.platform === 'win32' && command === 'npm'
  const result = spawnSync(command, args, {
    cwd: resolve(root, cwd),
    stdio: 'inherit',
    env: { ...process.env, ...env },
    shell: npmNeedsWindowsShell,
  })
  if (result.error) throw result.error
  if (result.status !== 0) process.exit(result.status || 1)
}

function requireGo() {
  const result = spawnSync(goBinary, ['version'], {
    cwd: root,
    encoding: 'utf8',
  })
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim()
  const match = output.match(/\bgo(\d+)\.(\d+)/)

  if (result.error || result.status !== 0 || !match) {
    console.error(
      'Go compiler not found. Install Go 1.25 or newer, ensure `go` is on PATH, then run this command again.',
    )
    process.exit(127)
  }

  const major = Number(match[1])
  const minor = Number(match[2])
  if (major < 1 || (major === 1 && minor < 25)) {
    console.error(`Go 1.25 or newer is required; found ${output}.`)
    process.exit(1)
  }

  console.log(`Using ${output}`)
}

requireGo()

console.log('[1/3] Building Vue frontend...')
run('npm', ['ci'], 'frontend')
run('npm', ['run', 'build'], 'frontend')

console.log('[2/3] Embedding frontend assets...')
rmSync(resolve(root, 'backend/web'), { recursive: true, force: true })
mkdirSync(resolve(root, 'backend/web'), { recursive: true })
writeFileSync(resolve(root, 'backend/web/.gitkeep'), '')
cpSync(resolve(root, 'frontend/dist'), resolve(root, 'backend/web'), {
  recursive: true,
})

const executableName = `questrace-server${target === 'windows' ? '.exe' : ''}`
const output = resolve(
  root,
  'dist',
  `questrace-${version}-${target}-${arch}`,
)
rmSync(output, { recursive: true, force: true })
mkdirSync(output, { recursive: true })

console.log(`[3/3] Building Go server for ${target}/${arch}...`)
run(
  goBinary,
  [
    'build',
    '-trimpath',
    `-ldflags=-s -w -X github.com/kukusuyi/Questrace/backend/internal/pkg/buildinfo.Version=${version}`,
    '-o',
    resolve(output, executableName),
    './cmd/api',
  ],
  'backend',
  { GOOS: target, GOARCH: arch, CGO_ENABLED: '0' },
)

if (target === 'linux') {
  writeFileSync(
    resolve(output, 'start.sh'),
    '#!/bin/sh\nset -eu\nHERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec "$HERE/questrace-server" "$@"\n',
  )
  chmodSync(resolve(output, 'start.sh'), 0o755)
}

if (target === 'darwin' || target === 'windows') {
  mkdirSync(resolve(root, 'desktop/resources'), { recursive: true })
  cpSync(
    resolve(output, executableName),
    resolve(root, 'desktop/resources', executableName),
  )
}

console.log(`Built ${output}`)
