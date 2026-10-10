const { readFileSync, readdirSync, writeFileSync } = require('node:fs')
const path = require('node:path')
const { zipSync } = require('fflate')

const files = {}
for (const entry of readdirSync('dist', { recursive: true, withFileTypes: true })) {
  if (!entry.isFile()) continue
  const filename = path.join(entry.parentPath, entry.name)
  const archivePath = path.relative('dist', filename).split(path.sep).join('/')
  if (archivePath !== 'function.zip') files[archivePath] = readFileSync(filename)
}

writeFileSync('dist/function.zip', zipSync(files, { level: 9, os: 3, attrs: 0o100644 << 16 }))
