const newman = require('newman')
const AWS = require('aws-sdk')
const codedeploy = new AWS.CodeDeploy({ apiVersion: '2014-10-06', region: 'us-west-2' })
const s3 = new AWS.S3({ apiVersion: '2014-10-06', region: 'us-west-2' })
const fs = require('fs')

exports.handler = async function (event, context) {
  console.log(event)

  // Workaround for CodeDeploy bug.
  // Give the ALB 10 seconds to make sure the test TG has switched to the new code.
  await sleep(10000)

  let errorFromTests

  const collectionFile = await downloadFileFromBucket(process.env.POSTMAN_COLLECTION)
  const environmentFile = await downloadFileFromBucket(process.env.POSTMAN_ENVIRONMENT)

  await runTests(collectionFile, environmentFile).catch(err => { errorFromTests = err })

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

function downloadFileFromBucket (key) {
  try {
    console.log(`getting ${key} from bucket`)
    return new Promise((resolve, reject) => {
      s3.getObject({
        Bucket: process.env.S3_BUCKET,
        Key: key
      }, (err, data) => {
        if (err) {
          console.error(`error trying to get object from bucket: ${err}`)
          reject(err)
        } else {
          console.log('no error, writing to file')

          fs.writeFileSync(`./.postman/${key}`, data.Body.toString());
          console.log(`wrote to ./.postman/${key}`)
          resolve(`./.postman/${key}`)
        }
      })
    })
  } catch (err) {
    console.log(err)
    throw err
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
  return new Promise(resolve => setTimeout(resolve, ms))
}

// runTests('../../../.postman')
