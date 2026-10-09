const assert = require('node:assert/strict')
const { test, beforeEach, afterEach } = require('node:test')
const fs = require('node:fs/promises')
const os = require('node:os')
const path = require('node:path')
const { createServer } = require('node:http')
const { once } = require('node:events')
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3')
const { CodeDeployClient, PutLifecycleEventHookExecutionStatusCommand } = require('@aws-sdk/client-codedeploy')

let tmpDir
let handler

beforeEach(async t => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'postman-lambda-test-'))
  const previousEnv = { ...process.env }
  Object.assign(process.env, {
    TMP_DIR: tmpDir,
    ALB_WAIT_TIME: '0',
    S3_BUCKET: 'test-bucket',
    TEST_ENV_VAR_OVERRIDES: '{}',
    POSTMAN_COLLECTIONS: JSON.stringify([{ collection: 'nested/collection.json', environment: null }])
  })
  t.after(() => {
    process.env = previousEnv
  })
  t.mock.method(console, 'log', () => {})
  t.mock.method(console, 'error', () => {})
  delete require.cache[require.resolve('../src/index.js')]
  handler = require('../src/index.js').handler
})

afterEach(async () => {
  await fs.rm(tmpDir, { recursive: true, force: true })
})

function mockCollection (t, collection) {
  return t.mock.method(S3Client.prototype, 'send', async command => {
    assert.ok(command instanceof GetObjectCommand)
    assert.deepEqual(command.input, { Bucket: 'test-bucket', Key: 'collection.json' })
    return { Body: { transformToString: async () => JSON.stringify(collection) } }
  })
}

function mockCodeDeploy (t) {
  return t.mock.method(CodeDeployClient.prototype, 'send', async command => {
    assert.ok(command instanceof PutLifecycleEventHookExecutionStatusCommand)
    return {}
  })
}

const deploymentEvent = { DeploymentId: 'deployment-id', LifecycleEventHookExecutionId: 'hook-id' }
const emptyCollection = { info: { name: 'test', schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json' }, item: [] }

test('downloads the S3 response stream and reports a successful deployment', async t => {
  const s3 = mockCollection(t, emptyCollection)
  const codedeploy = mockCodeDeploy(t)
  await handler(deploymentEvent)
  assert.equal(s3.mock.callCount(), 1)
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(tmpDir, 'collection.json'), 'utf8')), emptyCollection)
  assert.deepEqual(codedeploy.mock.calls[0].arguments[0].input, {
    deploymentId: 'deployment-id',
    lifecycleEventHookExecutionId: 'hook-id',
    status: 'Succeeded'
  })
})

test('reports S3 download failures to CodeDeploy and rejects the invocation', async t => {
  const failure = new Error('S3 access denied')
  t.mock.method(S3Client.prototype, 'send', async () => { throw failure })
  const codedeploy = mockCodeDeploy(t)
  await assert.rejects(handler(deploymentEvent), failure)
  assert.equal(codedeploy.mock.calls[0].arguments[0].input.status, 'Failed')
})

test('rejects invocations that omit the collection configuration', async () => {
  delete process.env.POSTMAN_COLLECTIONS
  await assert.rejects(handler({}), /POSTMAN_COLLECTIONS is required/)
})

test('runs Newman requests with environment overrides and rejects failed assertions', async t => {
  const server = createServer((request, response) => {
    response.writeHead(200, { 'Content-Type': 'application/json' })
    response.end(JSON.stringify({ path: request.url }))
  })
  server.listen(0, '127.0.0.1')
  await once(server, 'listening')
  t.after(() => new Promise(resolve => server.close(resolve)))
  const collection = {
    ...emptyCollection,
    item: [{
      name: 'local request',
      request: { method: 'GET', url: `http://127.0.0.1:${server.address().port}/{{target}}` },
      event: [{
        listen: 'test',
        script: {
          type: 'text/javascript',
          exec: [
            'pm.test("environment override", () => pm.expect(pm.response.json().path).to.equal("/override"));',
            'pm.test("expected status", () => pm.response.to.have.status(Number(pm.environment.get("expectedStatus"))));'
          ]
        }
      }]
    }]
  }
  mockCollection(t, collection)
  const codedeploy = mockCodeDeploy(t)
  process.env.TEST_ENV_VAR_OVERRIDES = JSON.stringify({ target: 'override', expectedStatus: '200' })
  await handler(deploymentEvent)
  assert.equal(codedeploy.mock.calls[0].arguments[0].input.status, 'Succeeded')
  process.env.TEST_ENV_VAR_OVERRIDES = JSON.stringify({ target: 'override', expectedStatus: '500' })
  await assert.rejects(handler(deploymentEvent))
  assert.equal(codedeploy.mock.calls[1].arguments[0].input.status, 'Failed')
})
