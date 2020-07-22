const fetch = require('node-fetch')
const fs = require('fs/promises')
const newman = require('newman')
const AWS = require('aws-sdk')
const codedeploy = new AWS.CodeDeploy({ apiVersion: '2014-10-06', region: 'us-west-2' })
const s3 = new AWS.S3({ apiVersion: '2014-10-06', region: 'us-west-2' })

const tmpDir = process.env.TMP_DIR ? process.env.TMP_DIR : '/tmp'

exports.handler = async function (event, context) {
  console.log(event)
  // Workaround for CodeDeploy bug.
  // Give the ALB 10 seconds to make sure the test TG has switched to the new code.
  const timer = sleep(10000)

  if (process.env.POSTMAN_API_KEY) {
    // start downloading postman files from Postman API
    const downloadCollection = downloadFileFromPostman('collection', process.env.POSTMAN_COLLECTION_NAME)
    const downloadEnv = downloadFileFromPostman('environment', process.env.POSTMAN_ENVIRONMENT_NAME)
    await downloadCollection
    await downloadEnv
  } else {
    // start downloading postman files from S3 Bucket
    const downloadCollection = downloadFileFromBucket('collection', process.env.POSTMAN_COLLECTION)
    const downloadEnv = downloadFileFromBucket('environment', process.env.POSTMAN_ENVIRONMENT)
    await downloadCollection
    await downloadEnv
  }

  let errorFromTests
  const postmanTests = runTests(
    `${tmpDir}/collection.json`,
    `${tmpDir}/environment.json`
  ).catch(err => { errorFromTests = err })

  await postmanTests
  await timer

  const deploymentId = event.DeploymentId
  if (deploymentId) {
    console.log('starting to update CodeDeploy lifecycle event hook status...')
    const params = {
      deploymentId: event.DeploymentId,
      lifecycleEventHookExecutionId: event.LifecycleEventHookExecutionId,
      status: errorFromTests ? 'Failed' : 'Succeeded'
    }
    try {
      const data = await codedeploy.putLifecycleEventHookExecutionStatus(params).promise()
      console.log(data)
    } catch (err) {
      console.log(err, err.stack)
      throw err
    }
  } else {
    console.log('No deployment ID found in the event. Skipping update to CodeDeploy lifecycle hook...')
  }

  if (errorFromTests) throw errorFromTests // Cause the lambda to "fail"
}

async function downloadFileFromPostman (type, name) {
  console.log(`started download for ${tmpDir}/${type}.json`)
  try {
    const response = await fetch(`https://api.getpostman.com/${type}s`, {
      method: 'GET',
      headers: {
        'X-Api-Key': process.env.POSTMAN_API_KEY
      }
    })
    const json = await response.json()
    // console.log(JSON.stringify(json))
    const list = json[`${type}s`]
    // console.log(JSON.stringify(list))
    const found = list.find(c => c.name === name)
    // console.log(JSON.stringify(found))
    const uid = found.uid

    const actualResponse = await fetch(`https://api.getpostman.com/${type}s/${uid}`, {
      method: 'GET',
      headers: {
        'X-Api-Key': process.env.POSTMAN_API_KEY
      }
    })
    await fs.writeFile(`${tmpDir}/${type}.json`, await actualResponse.text())
    console.log(`downloaded ${tmpDir}/${type}.json`)
  } catch (error) {
    console.error('Error in fetch', error)
  }
}

async function downloadFileFromBucket (type, key) {
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

  await fs.writeFile(`${tmpDir}/${type}.json`, data.Body.toString())
  console.log(`downloaded ${tmpDir}/${type}.json`)
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
