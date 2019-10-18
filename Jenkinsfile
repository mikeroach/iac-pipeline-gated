pipeline {
    agent any 
    options {
        skipDefaultCheckout() // Perform this inside the pipeline after forced git-crypt reset.
        skipStagesAfterUnstable()
    }
    environment {
        /* Setting this environment variable allows us to omit a persistent Google Cloud SDK
        configuration and still use those pesky third-party Terraform modules that run gcloud
        helper scripts via local-exec provisioners. */
        CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE = "secrets/project-factory-seed-service-account.json"
    }
    stages {
        stage('Checkout and Unlock Repository'){
            environment {
                GIT_CRYPT_KEY = credentials('GitCrypt_Key_iac-pipeline-gated')
            }
            steps {
                // Perform SCM checkout from within pipeline and decrypt repository secret files
                sh label: 'Reset git-crypt status before SCM checkout', script: 'git-crypt lock --force', returnStatus: true
                checkout scm
                sh label: 'Decrypt repository with git-crypt', script: 'git-crypt unlock ${GIT_CRYPT_KEY}'
                sendNotifications 'STARTED'
            }
        }
        stage('Terraform Tests') {
            steps {
                sh label: 'Run Terraform initialization and validation checks', script: 'make test'
            }
        }
        stage('Generate Terraform Plan') {
            steps {
                sh label: 'Ensure Terraform plan generation succeeds', script: 'make plan'
            }
        }
        stage('Apply Terraform Plan') {
            when {
                branch 'master'
            } 
            steps {
                sh label: 'Apply Terraform plan changes', script: 'make apply'
            }
        }
        stage('Integration Tests') {
            when {
                branch 'master'
            }
            steps {
                sleep(time:30, unit:"SECONDS") // Wait 30 seconds for DDNS daemon set to register new address, if applicable.
                sh label: 'Run HTTP check against newly applied changes', script: '/usr/lib/nagios/plugins/check_http -H `make -s http-host` -v -u "/"'
            }
        }
    }
    post {
      success {
            script {
                if (env.CHANGE_ID) { // Only interact with pull requests if this job was triggered by one
                    pullRequest.comment('[Jenkins] All tests for this PR succeeded, please manually review.')
                }
            }
        }
        cleanup {
            sh label: 'Lock repository secret files', script: 'git-crypt lock --force', returnStatus: true
            sendNotifications currentBuild.result
        }
    }
}

// Retrieve changelog for notifications adapted from https://support.cloudbees.com/hc/en-us/articles/217630098-How-to-access-Changelogs-in-a-Pipeline-Job-
def getChangeString() {
 MAX_MSG_LEN = 100
 def changeString = ""

 echo "Gathering SCM changes"
 def changeLogSets = currentBuild.changeSets
 for (int i = 0; i < changeLogSets.size(); i++) {
 def entries = changeLogSets[i].items
 for (int j = 0; j < entries.length; j++) {
 def entry = entries[j]
 truncated_msg = entry.msg.take(MAX_MSG_LEN)
 changeString += " - ${truncated_msg} [${entry.author}]\n"
 }
 }

 if (!changeString) {
 changeString = " - No new changes"
 }
 return changeString
}

// Send Slack notifications adapted from https://jenkins.io/blog/2017/02/15/declarative-notifications/
/* MIT License

Copyright (c) 2017 Liam Newman

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. */
def sendNotifications(String buildStatus = 'STARTED') {
  // build status of null means successful
  buildStatus = buildStatus ?: 'SUCCESS'

  // Default values
  def colorName = 'RED'
  def colorCode = '#FF0000'
  def emoji = ":question:"
  def subject = "${buildStatus}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'"
  def summary = "${subject} (${env.BUILD_URL})"
    
  // Override default values based on build status
  if (buildStatus == 'STARTED') {
    emoji = ":construction:"
    color = 'YELLOW'
    colorCode = '#FFFF00'
    summary = "${emoji} ${subject} (${env.BUILD_URL})\n " + getChangeString()
  } else if (buildStatus == 'SUCCESS') {
    emoji = ":white_check_mark:"
    color = 'GREEN'
    colorCode = '#00FF00'
    summary = "${emoji} ${subject} (${env.BUILD_URL})"
  } else {
    emoji = ":x:"
    color = 'RED'
    colorCode = '#FF0000'
    summary = "${emoji} ${subject} (${env.BUILD_URL})" 
  }

  // Send notifications
  slackSend (channel: "roachtest", color: colorCode, message: summary)
}