pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps {
        // Checks out the branch configured on the Jenkins job SCM
        checkout scm
        echo "Checked out: ${env.GIT_BRANCH ?: 'SCM default branch'}"
      }
    }

    stage('Test') {
      steps {
        echo 'testing please ensure !!'
      }
    }
  }
}
