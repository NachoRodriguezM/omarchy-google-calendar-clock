// Check catalog completeness and placeholder preservation without Qt.
const fs = require('fs')
const path = require('path')
const dir = __dirname
const english = JSON.parse(fs.readFileSync(path.join(dir, 'en.json'), 'utf8'))
const placeholders = value => (String(value).match(/%\d+/g) || []).sort().join(',')
let errors = 0
for (const file of fs.readdirSync(dir).filter(name => name.endsWith('.json'))) {
  const catalog = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'))
  for (const [key, source] of Object.entries(english)) {
    if (typeof catalog[key] !== 'string' || !catalog[key].trim()) {
      console.error(`${file}: missing ${key}`)
      errors++
    } else if (placeholders(catalog[key]) !== placeholders(source)) {
      console.error(`${file}: placeholder mismatch in ${key}`)
      errors++
    }
  }
  for (const key of Object.keys(catalog)) {
    if (!(key in english)) {
      console.error(`${file}: unexpected ${key}`)
      errors++
    }
  }
}
if (errors) process.exitCode = 1
else console.log('All available catalogs have complete keys and matching placeholders.')
