properties([parameters([string(defaultValue: '<values.yaml>', description: 'Input the values file name', name: 'values_file')])])

pipeline {
    agent any 
    stages {
        stage('Git Checkout') { 
            steps {
                checkout([$class: 'GitSCM', branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/vmunde62/vault-csi.git']]])
            }
        }
        stage('Setting Environment') {
            steps {
                script {
                    env.clusterName = sh( script: "cat ${params.values_file} | grep clusterName | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.nameSpace = sh( script: "cat ${params.values_file} | grep nameSpace | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.kubernetesMountPath = sh( script: "cat ${params.values_file} | grep kubernetesMountPath | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.secretsPath = sh( script: "cat ${params.values_file} | grep secretsPath | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.policyName = sh( script: "cat ${params.values_file} | grep policyName | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.vaultRole = sh( script: "cat ${params.values_file} | grep vaultRole | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.saName = sh( script: "cat ${params.values_file} | grep saName | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.kserver = sh( script: "cat ${params.values_file} | grep kserver | cut -d ' ' -f 4", returnStdout: true ).trim()
                    env.vaultServer = sh( script: "cat ${params.values_file} | grep vaultServer | cut -d ' ' -f 4", returnStdout: true ).trim()
                }
            }
        }
        stage('CSI Setup') {
            steps {
                withKubeConfig(clusterName: "${env.clusterName}", contextName: "${env.clusterName}", credentialsId: 'kubeconfig', namespace: "${env.nameSpace}", serverUrl: "${env.kserver}") {
                sh 'kubectl get pods'
                sh "kubectl create namespace ${env.nameSpace} || true"
                sh "kubectl create sa $saName || true"
                sh 'helm repo add hashicorp https://helm.releases.hashicorp.com'
                sh 'helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts'
                sh 'helm repo update'
                sh 'helm install vault hashicorp/vault --values csi-helm/values.yaml || true'
                sleep(15)
                sh 'helm install csi secrets-store-csi-driver/secrets-store-csi-driver || true'
                sleep(10)
                }
            }
        }
        stage('Vault Authentication') {
            steps {
                withKubeConfig(clusterName: "${env.clusterName}", contextName: "${env.clusterName}", credentialsId: 'kubeconfig', namespace: "${env.nameSpace}", serverUrl: "${env.kserver}") {
                    script {
                        env.TOKEN_REVIEW_JWT = sh( script: "scripts/vault_helm_secret.sh", returnStdout: true).trim()
                        env.KUBE_CA_CERT= sh( script: "scripts/kube_ca_cert.sh", returnStdout: true).trim()
                        env.KUBE_HOST= sh( script: "scripts/kube_host.sh", returnStdout: true).trim()            
                    }
                withCredentials([[$class: 'VaultTokenCredentialBinding', credentialsId: 'vault_auth', vaultAddr: "${env.vaultServer}"]]) {
                    sh "vault auth enable --path=$kubernetesMountPath kubernetes || true"
                    sh """
                        vault write auth/$kubernetesMountPath/config \
                        token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
                        kubernetes_host="$KUBE_HOST" \
                        kubernetes_ca_cert="$KUBE_CA_CERT" \
                        issuer="https://kubernetes.default.svc.cluster.local"
                        """
                    sh """
                        echo -e "path \\"$secretsPath\\" {\\n  capabilities = [\\"read\\"]\\n}" > policy.hcl
                        vault policy write $policyName policy.hcl
                        """
                    sh """
                        vault write auth/$kubernetesMountPath/role/$vaultRole \
                        bound_service_account_names=$saName \
                        bound_service_account_namespaces=$nameSpace \
                        policies=$policyName \
                        ttl=24h
                        """
                    }
                }
            }
        }
        stage('App Deploy') {
            steps {
                withKubeConfig(clusterName: "${env.clusterName}", contextName: "${env.clusterName}", credentialsId: 'kubeconfig', namespace: "${env.nameSpace}", serverUrl: "${env.kserver}") {
                    sh "helm install webapp webapp-helm --values ${params.values_file} || true"
                }
            }
                    
        }
    }
}