pipeline {
    agent any 
    stages {
        stage('Git checkout') { 
            steps {
                checkout([$class: 'GitSCM', branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/vmunde62/vault-csi.git']]])
            }
        }
        stage('CSI setup') {
            steps {
               withKubeConfig([credentialsId: 'mykubeconfig', serverUrl: 'https://192.168.49.2:8443']) {
      sh 'kubectl apply -f my-kubernetes-directory'
            }
        }
    }
}
