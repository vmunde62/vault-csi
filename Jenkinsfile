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
                sh '''helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
kubectl get pods'''
            }
        }
    }
}
