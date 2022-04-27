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
            sh 'helm install vault hashicorp/vault --values csi-helm/values.yaml || true'
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
                withCredentials([[$class: 'VaultTokenCredentialBinding', credentialsId: 'vault_auth', vaultAddr: 'http://0.0.0.0:8200']]) {
            sh "vault auth enable --path=${params.cluster} kubernetes || true"
            sh """
                vault write auth/${params.cluster}/config \
                token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
                kubernetes_host="$KUBE_HOST" \
                kubernetes_ca_cert="$KUBE_CA_CERT" \
                issuer="https://kubernetes.default.svc.cluster.local"
                """
            sh """
                echo -e "path \\"secret/data/keypair\\" {\\n  capabilities = [\\"read\\"]\\n}" > policy.hcl
                vault policy write cluster-a-app policy.hcl
                """
            sh """
                vault write auth/${params.cluster}/role/cluster1-role \
                bound_service_account_names=default \
                bound_service_account_namespaces=${params.nameSpace} \
                policies=cluster-a-app \
                ttl=24h
                """
                    }
                }
            }
        }
        stage('App Deploy') {
            steps {
                withKubeConfig(clusterName: "${params.cluster}", contextName: "${params.cluster}", credentialsId: 'kubeconfig', namespace: "${params.nameSpace}", serverUrl: 'https://192.168.58.2:8443/') {
            sh "helm install webapp webapp-helm --values webapp-helm/c1values.yaml"
                }
            }
                    
        }
    }
}