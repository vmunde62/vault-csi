#!/bin/bash

# Please check that values.yaml file is configured and present in current directory.
# Provide your values for the envirnment variable and double check it.
# Don't use capital letters for vaules.
 
authMountPath=cluster-a                 # The vault mount path for authentication.
vaultRoleName=cluster1-role             # The role name for setting authentication.
vaultPolicyName=cluster-a-app-policy    # The name for the policy to access secrets.

vaultSecretPath=cluster1                # The path name where the secrets are located in vault.
crtName=tls.crt                         # Provide .crt keyname located in secrets.
keyName=tls.key                         # Provide .crt keyname located in secrets.
passName=jkspass                        # Provide password for generating jks

saName=cluster1                         # Service account which will bound to the auth role.
saNamespace=default                     # The Namespace where service account will be created. 
spcName=vault-database-cluster-2        # Name of the secret provider class

EXTERNAL_VAULT_ADDR=192.168.49.1        # Minikube host address
VAULT_ADDR='http://0.0.0.0:8200'        # Vault address in respect to kubernetes host


# CSI (Container storage interface for vault) PROVIDER AND DRIVER DEPLOY

echo 'Setting up Container storage interface for vault..'

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update

sleep 5
echo 'Deploying vault-csi-provider..'
helm install vault hashicorp/vault --values values.yaml --wait
echo 'Deploying vault-csi-provider..'
until echo "$(kubectl get pods -l=app.kubernetes.io/name=vault-csi-provider -o jsonpath='{.items[*].status.containerStatuses[0].ready}')" | grep -q "true"; do
   echo 'waiting for deployment to be completed..' 
   sleep 8
done

sleep 5
echo 'Deploying vault-csi-driver'
helm install csi secrets-store-csi-driver/secrets-store-csi-driver
echo 'Deploying vault-csi-provider..'
until echo "$(kubectl get pods -l=app.kubernetes.io/name=secrets-store-csi-driver -o jsonpath='{.items[*].status.containerStatuses[0].ready}')" | grep -q "true"; do
   echo 'waiting for deployment to be completed..' 
   sleep 8
done

# VAULT AUTHENTICATION STEPS
echo 'Exporting tokens..'

VAULT_HELM_SECRET_NAME=$(kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name')
TOKEN_REVIEW_JWT=$(kubectl get secret $VAULT_HELM_SECRET_NAME --output='go-template={{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')


# setting vault auth path
echo 'Setting vault auth..'
export VAULT_ADDR='http://0.0.0.0:8200'
sleep 2
vault login root
sleep 2

vault auth enable --path=$authMountPath kubernetes


# setting token and certificate for authentication
vault write auth/$authMountPath/config \
    token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
    kubernetes_host="$KUBE_HOST" \
    kubernetes_ca_cert="$KUBE_CA_CERT" \
    issuer="https://kubernetes.default.svc.cluster.local"
    

# setting policy for the given secret path
echo 'Setting vault policy..'

vault policy write $vaultPolicyName - <<EOF
path "secret/data/$vaultSecretPath" {
  capabilities = ["read"]
}
path "secret/metadata/$vaultSecretPath" {
  capabilities = ["read"]
}
EOF


# setting up role for secret access
echo 'Creating role for secret access..'

vault write auth/$authMountPath/role/$vaultRoleName\
     bound_service_account_names=$saName \
     bound_service_account_namespaces=$saNamespace \
     policies=$vaultPolicyName \
     ttl=24h
     

# SET VAULT ENDPOINT
# create external vault service and endpoint.

echo 'Creating vault service and endpoints..'

cat > external-vault.yaml <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: external-vault
  namespace: default
spec:
  ports:
  - protocol: TCP
    port: 8200
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-vault
subsets:
  - addresses:
      - ip: $EXTERNAL_VAULT_ADDR
    ports:
      - port: 8200
EOF

sleep 2
kubectl apply --filename external-vault.yaml


# CREATE SECRET PROVIDER CLASS
echo 'Creating secret provider class..'

cat > spc-vault-database.yaml <<EOF
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: $spcName
spec:
  provider: vault
  parameters:
    vaultAddress: "http://external-vault:8200"
    vaultKubernetesMountPath: "$authMountPath"
    roleName: "$vaultRoleName"
    objects: |
      - objectName: "tls-crt"
        secretPath: "secret/data/$vaultSecretPath"
        secretKey: "$crtName"
      - objectName: "tls-key"
        secretPath: "secret/data/$vaultSecretPath"
        secretKey: "$keyName"
      - objectName: "jkspass"
        secretPath: "secret/data/$vaultSecretPath"
        secretKey: "$passName"

EOF

sleep 2
kubectl apply --filename spc-vault-database.yaml


#Creating Service Account
echo 'Creating service account..'
sleep 2
kubectl create serviceaccount $saName
sleep 2


# APP DEPLOY
# If you do not want to deploy the webapp, then comment out 'kubectl apply' command
echo 'Deploying Webapp..'

cat > webapp.yaml <<EOF
kind: Pod
apiVersion: v1
metadata:
  name: webapp-$vaultSecretPath
spec:
  serviceAccountName: $saName
  containers:
  - image: jweissig/app:0.0.1
    name: webapp-$vaultSecretPath
    volumeMounts:
    - name: jksfile
      mountPath: /mnt/jksfile
  initContainers:
  - name: keystore
    image: openjdk:11-jdk
    env:
      - name: keyfile
        value: /mnt/secrets-store/tls-key
      - name: crtfile
        value: /mnt/secrets-store/tls-crt
      - name: keystore_pkcs12
        value: /mnt/jksfile/keystore.pkcs12
      - name: keystore_jks
        value: /mnt/jksfile/keystore.jks
      - name: password
        value: /mnt/secrets-store/jkspass
    command: ["/bin/sh", "-c"]
    args:
      - echo starting;
        sleep 15;
        openssl pkcs12 -export -inkey \$keyfile -in \$crtfile -out \$keystore_pkcs12 -password pass:\$password;
        keytool -importkeystore -noprompt -srckeystore \$keystore_pkcs12 -srcstoretype pkcs12 -destkeystore \$keystore_jks -storepass \$password -srcstorepass \$password;
        echo end;
    volumeMounts:
    volumeMounts:
    - name: secrets-store-inline   #  Mounted this volume from the csi driver. 
      mountPath: "/mnt/secrets-store/"
      readOnly: true
    - name: jksfile
      mountPath: /mnt/jksfile

  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "$spcName"
    - name: jksfile
      emptyDir: {}
      
EOF

sleep 2
kubectl apply --filename webapp.yaml

echo 'Done. check the Deployment.'
