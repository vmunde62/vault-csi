properties([parameters([choice(choices: 'cluster1\ncluster2\ncluster3', description: 'Choose the cluster', name: 'cluster'), choice(choices: 'ns1\nns2\nns3', description: 'Choose the namespace', name: 'nameSpace')])])


pipeline {
    agent any 
    stages {
        stage('Git Checkout') { 
            steps {
                checkout([$class: 'GitSCM', branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/vmunde62/vault-csi.git']]])
            }
        }
        stage('CSI Setup') {
            steps {
                withKubeConfig(clusterName: "${params.cluster}", contextName: "${params.cluster}", credentialsId: 'kubeconfig', namespace: "${params.nameSpace}", serverUrl: 'https://192.168.58.2:8443/') {
            sh "kubectl create namespace ${params.nameSpace} || true"
            sh 'helm repo add hashicorp https://helm.releases.hashicorp.com'
            sh 'helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts'
            sh 'helm repo update'
            sh 'helm install vault hashicorp/vault --values values.yaml || true'
            sleep(15)
            sh 'helm install csi secrets-store-csi-driver/secrets-store-csi-driver || true'
                }
            }
        }
        stage('Vault Authentication') {
            steps {
                withKubeConfig(clusterName: "${params.cluster}", contextName: "${params.cluster}", credentialsId: 'kubeconfig', namespace: "${params.nameSpace}", serverUrl: 'https://192.168.58.2:8443/') {
            script {
             env.TOKEN_REVIEW_JWT = sh( script: "scripts/vault_helm_secret.sh",
                             returnStdout: true).trim()
             env.KUBE_CA_CERT= sh( script: "scripts/kube_ca_cert.sh",
                             returnStdout: true).trim()
             env.KUBE_HOST= sh( script: "scripts/kube_host.sh",
                             returnStdout: true).trim()            
                    }
            echo "${env.TOKEN_REVIEW_JWT}"
            echo "${env.KUBE_CA_CERT}"
            echo "${env.KUBE_HOST}"
                }
            }
        }
    }
}