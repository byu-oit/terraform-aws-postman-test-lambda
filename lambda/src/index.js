const fetch = require('node-fetch')
const fs = require('fs').promises
const os = require('os')
const { sep } = require('path')
const newman = require('newman')
const AWS = require('aws-sdk')
const path = require('path')
const codedeploy = new AWS.CodeDeploy({ apiVersion: '2014-10-06', region: 'us-west-2' })
const s3 = new AWS.S3({ apiVersion: '2014-10-06', region: 'us-west-2' })

const tmpDir = process.env.TMP_DIR || os.tmpdir()

exports.handler = async function (event, context) {
  console.log('event', event)
  const deploymentId = event.DeploymentId
  const combinedRunner = event.Combined
  if (deploymentId) {
    console.log(`After postman tests are complete, this will update the CodeDeploy deployment ${deploymentId}.`)
  } else if (combinedRunner) {
    console.log(`After postman tests are complete, this will return a pass/fail to the combined runner: ${combinedRunner}`)
  } else {
    console.log('No DeploymentId found in event, this will execute the postman tests and then exit.')
  }

  // Workaround for CodeDeploy bug.
  // Give the ALB 10 seconds to make sure the test TG has switched to the new code.
  const timer = sleep(10000)

  // store the error so that we can update codedeploy lifecycle if there are any errors including errors from downloading files
  let error

  try {
    const postmanCollections = process.env.POSTMAN_COLLECTIONS
    if (!postmanCollections) {
      error = new Error('Env variable POSTMAN_COLLECTIONS is required')
    } else {
      const postmanList = JSON.parse(postmanCollections)
      const promises = [timer]
      for (const each of postmanList) {
        if (each.collection.includes('.json')) {
          promises.push(downloadFileFromBucket(each.collection))
          each.collection = `${tmpDir}${sep}${path.basename(each.collection)}`
        } else {
          promises.push(downloadFileFromPostman('collection', each.collection))
          each.collection = `${tmpDir}${sep}${path.basename(each.collection)}.json`
        }
        if (each.environment) { // environment can be null
          if (each.environment.includes('.json')) {
            promises.push(downloadFileFromBucket(each.environment))
            each.environment = `${tmpDir}${sep}${path.basename(each.environment)}`
          } else {
            promises.push(downloadFileFromPostman('environment', each.environment))
            each.environment = `${tmpDir}${sep}${path.basename(each.environment)}.json`
          }
        }
      }
      // make sure all files are downloaded and we wait for 10 seconds before executing postman tests
      await Promise.all(promises)

      console.log('starting postman tests ...')
      if (!error) {
        // no need to run tests if files weren't downloaded correctly
        for (const each of postmanList) {
          if (!error) {
            // don't run later collections if previous one errored out
            await runTest(each.collection, each.environment).catch(err => {
              error = err
            })
          }
        }
      }
      console.log('postman tests finished')
    }
    await updateRunner(deploymentId, combinedRunner, event, error)
  } catch (e) {
    await updateRunner(deploymentId, combinedRunner, event, true)
    throw e
  }
  if (error) throw error // Cause the lambda to "fail"
}

async function downloadFileFromPostman (type, id) {
  const filename = `${tmpDir}${sep}${id}.json`
  console.log(`started download for ${filename}`)
  const response = await fetch(`https://api.getpostman.com/${type}s/${id}`, {
    method: 'GET',
    headers: {
      'X-Api-Key': process.env.POSTMAN_API_KEY
    }
  }).catch(err => {
    throw new Error(`Error trying to download ${type} ${id} from Postman API: ${err}`)
  })
  const data = await response.text()
  if (response.status !== 200) {
    const errorData = JSON.parse(data)
    throw new Error(`Error trying to download ${type} ${id} from Postman API: ${errorData.error.message}`)
  }
  await fs.writeFile(filename, data)
  console.log(`downloaded ${filename}`)
}

async function downloadFileFromBucket (key) {
  // Stripping relative path off of key.
  key = path.basename(key)

  const filename = `${tmpDir}${sep}${key}`
  console.log(`started download for ${key} from s3 bucket`)

  let data
  try {
    data = await s3.getObject({
      Bucket: process.env.S3_BUCKET,
      Key: key
    }).promise()
  } catch (err) {
    console.error(`error trying to get object from bucket: ${err}`)
    throw err
  }

  await fs.writeFile(filename, data.Body.toString())
  console.log(`downloaded ${filename}`)
  return filename
}

function newmanRun (options) {
  return new Promise((resolve, reject) => {
    newman.run(options, err => {
      err ? reject(err) : resolve()
    })
  })
}

async function runTest (postmanCollection, postmanEnvironment) {
  try {
    console.log(`running postman test for ${postmanCollection}`)
    await newmanRun({
      collection: postmanCollection,
      environment: postmanEnvironment,
      reporters: 'cli',
      abortOnFailure: true,
      envVar: generateEnvVars()
    })
    console.log('collection run complete!')
  } catch (err) {
    console.log(err)
    throw err
  }
}

async function updateRunner (deploymentId, combinedRunner, event, error) {
  if (deploymentId) {
    console.log('starting to update CodeDeploy lifecycle event hook status...')
    const params = {
      deploymentId: deploymentId,
      lifecycleEventHookExecutionId: event.LifecycleEventHookExecutionId,
      status: error ? 'Failed' : 'Succeeded'
    }
    try {
      const data = await codedeploy.putLifecycleEventHookExecutionStatus(params).promise()
      console.log(data)
    } catch (err) {
      console.log(err, err.stack)
      throw err
    }
  } else if (combinedRunner) {
    return {
      passed: !error
    }
  } else {
    console.log('No deployment ID found in the event. Skipping update to CodeDeploy lifecycle hook...')
  }
}

function generateEnvVars () {
  const envVarsArray = []
  const parsedVars = JSON.parse(process.env.TEST_ENV_VAR_OVERRIDES, 'base64')
  if (Object.keys(parsedVars).length === 0) return envVarsArray
  for (const [key, value] of Object.entries(parsedVars)) {
    envVarsArray.push({ key, value })
  }
  return envVarsArray
}

function sleep (ms) {
  console.log('started sleep timer')
  return new Promise(resolve => setTimeout(args => {
    console.log('ended sleep timer')
    resolve()
  }, ms))
}

// exports.handler({}, {}).then(() => {})
