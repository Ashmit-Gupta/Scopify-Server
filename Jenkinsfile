# Scopify Server — deploy manifests only
#
# CI/CD for the backend lives in the scopify-backend repo:
#   https://github.com/Ashmit-Gupta/scopify-backend → Jenkinsfile
#
# That pipeline clones this repo in the Deploy stage and applies:
#   k8s/scopify-backend/dev/   (branch dev)
#   k8s/scopify-backend/prod/  (branch main)
#
# See k8s/README.md for one-time secret setup.

pipeline {
    agent any

    stages {
        stage('Info') {
            steps {
                echo '''
                This repo holds K8s manifests under k8s/.
                Run the Jenkins job from the scopify-backend repository instead.
                '''
            }
        }
    }
}
