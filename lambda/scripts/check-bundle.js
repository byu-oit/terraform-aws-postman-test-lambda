const assert = require('node:assert/strict')
const path = require('node:path')

const { handler } = require(path.resolve(process.argv[2]))
assert.equal(typeof handler, 'function')
process.env.ALB_WAIT_TIME = '0'
process.env.POSTMAN_COLLECTIONS = '[]'
handler({}).catch(error => {
  console.error(error)
  process.exitCode = 1
})
