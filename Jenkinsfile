pipeline {
  agent any
  stages {
    stage('Checking') {
      steps {
        sh 'make check'
      }
    }
    stage('Build') {
      steps {
        sh 'make all'
      }
    }
  }
}