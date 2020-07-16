const util = require('util')
const fetch = require('node-fetch')
const fs = require('fs')
const streamPipeline = util.promisify(require('stream').pipeline)
const newman = require('newman')
const AWS = require('aws-sdk')
const codedeploy = new AWS.CodeDeploy({ apiVersion: '2014-10-06', region: 'us-west-2' })

exports.handler = async function (event, context) {
  console.log(event)

  // Workaround for CodeDeploy bug.
  // Give the ALB 10 seconds to make sure the test TG has switched to the new code.
  const timer = sleep(10000)

  // start downloading postman files
  const downloadCollection = downloadFileFromPostman('collection', process.env.POSTMAN_COLLECTION_NAME)
  const downloadEnv = downloadFileFromPostman('environment', process.env.POSTMAN_ENVIRONMENT_NAME)

  await downloadCollection
  await downloadEnv

  let errorFromTests
  const postmanTests = runTests(
    './collection.json',
    './environment.json'
  ).catch(err => { errorFromTests = err })

  await postmanTests
  await timer

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

  if (errorFromTests) throw errorFromTests // Cause the lambda to "fail"
}

async function downloadFileFromPostman (type, name) {
  console.log(`started download for ./${type}.json`)
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
    await streamPipeline(actualResponse.body, fs.createWriteStream(`./${type}.json`))
    console.log(`downloaded ./${type}.json`)
  } catch (error) {
    console.error('Error in fetch', error)
  }
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

// runTests('../../../.postman')
// exports.handler({}, {})
