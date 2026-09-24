import { appendFileSync, readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const desktopVersion = JSON.parse(
  readFileSync(resolve(root, 'desktop/package.json'), 'utf8'),
).version
const frontendVersion = JSON.parse(
  readFileSync(resolve(root, 'frontend/package.json'), 'utf8'),
).version
const flutterManifest = readFileSync(
  resolve(root, 'mobile/flutter_app/pubspec.yaml'),
  'utf8',
)
const flutterVersion = flutterManifest.match(/^version:\s*([^+\s]+)(?:\+\d+)?$/m)?.[1]
const expectedVersion = process.argv[2] || desktopVersion

const versions = {
  'desktop/package.json': desktopVersion,
  'frontend/package.json': frontendVersion,
  'mobile/flutter_app/pubspec.yaml': flutterVersion,
}

for (const [file, version] of Object.entries(versions)) {
  if (version !== expectedVersion) {
    throw new Error(`${file} has version ${version ?? '<missing>'}; expected ${expectedVersion}`)
  }
}

if (process.env.GITHUB_OUTPUT) {
  appendFileSync(process.env.GITHUB_OUTPUT, `version=${expectedVersion}\n`)
}

console.log(`Notebook version ${expectedVersion} is consistent across all packages.`)
