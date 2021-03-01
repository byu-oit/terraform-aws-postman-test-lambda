const fetch = require('node-fetch')
const fs = require('fs').promises
const os = require('os')
const { sep } = require('path')
const newman = require('newman')
const AWS = require('aws-sdk')
const codedeploy = new AWS.CodeDeploy({ apiVersion: '2014-10-06', region: 'us-west-2' })
const s3 = new AWS.S3({ apiVersion: '2014-10-06', region: 'us-west-2' })

const tmpDir = process.env.TMP_DIR || os.tmpdir()

exports.handler = async function (event, context) {
  console.log(event)
  // Workaround for CodeDeploy bug.
  // Give the ALB 10 seconds to make sure the test TG has switched to the new code.
  const timer = sleep(10000)

  // store the error so that we can update codedeploy lifecycle if there are any errors including errors from downloading files
  let error
  if (process.env.POSTMAN_API_KEY) {
    // download postman files from Postman API
    await Promise.all([
      downloadFileFromPostman('collection', process.env.POSTMAN_COLLECTION_NAME),
      downloadFileFromPostman('environment', process.env.POSTMAN_ENVIRONMENT_NAME)
    ]).catch(err => { error = err })
  } else {
    // download postman files from S3 Bucket
    await Promise.all([
      downloadFileFromBucket('collection', process.env.POSTMAN_COLLECTION),
      downloadFileFromBucket('environment', process.env.POSTMAN_ENVIRONMENT)
    ]).catch(err => { error = err })
  }

  // finish the 10 second timer before trying to run the postman tests
  await timer
  if (!error) {
    // no need to run tests if files weren't downloaded correctly
    await runTests(
      `${tmpDir}${sep}collection.json`,
      `${tmpDir}${sep}environment.json`
    ).catch(err => { error = err })
  }

  const deploymentId = event.DeploymentId
  const combinedRunner = event.Combined
  if (deploymentId) {
    console.log('starting to update CodeDeploy lifecycle event hook status...')
    const params = {
      deploymentId: event.DeploymentId,
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
      'passed': !error
    }
  } else {
    console.log('No deployment ID found in the event. Skipping update to CodeDeploy lifecycle hook...')
  }

  if (error) throw error // Cause the lambda to "fail"
}

async function downloadFileFromPostman (type, name) {
  const filename = `${tmpDir}${sep}${type}.json`
  console.log(`started download for ${filename}`)
  const response = await fetch(`https://api.getpostman.com/${type}s`, {
    method: 'GET',
    headers: {
      'X-Api-Key': process.env.POSTMAN_API_KEY
    }
  })
  const json = await response.json()
  const list = json[`${type}s`]
  const found = list.filter(entry => entry.name === name)
  if (found.length > 1) {
    throw Error(`More than 1 ${type} files found with name '${name}'. Please make your ${type}'s name is unique.`)
  } else if (found.length === 0) {
    throw Error(`No ${type} found with name '${name}'.`)
  } else {
    const uid = found[0].uid
    console.log(`Found uid (${uid}) for ${type} with name = ${name}`)
    const actualResponse = await fetch(`https://api.getpostman.com/${type}s/${uid}`, {
      method: 'GET',
      headers: {
        'X-Api-Key': process.env.POSTMAN_API_KEY
      }
    })
    await fs.writeFile(filename, await actualResponse.text())
    console.log(`downloaded ${filename}`)
  }
}

async function downloadFileFromBucket (type, key) {
  const filename = `${tmpDir}${sep}${type}.json`
  console.log(`started download for ${type} with key ${key} from s3 bucket`)

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
}

function newmanRun (options) {
  return new Promise((resolve, reject) => {
    newman.run(options, err => { err ? reject(err) : resolve() })
  })
}

async function runTests (postmanCollection, postmanEnvironment) {
  try {
    console.log('running postman tests')
    await newmanRun({
      collection: postmanCollection,
      environment: postmanEnvironment,
      reporters: 'cli',
      abortOnFailure: true
    })
    console.log('collection run complete!')
  } catch (err) {
    console.log(err)
    throw err
  }
}

function sleep (ms) {
  console.log('started sleep timer')
  return new Promise(resolve => setTimeout(resolve, ms))
}

// exports.handler({}, {})
