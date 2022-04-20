#!/bin/bash

# Setup keypairs in vault secrets
# Provide vault secret path for the keypair
VAULT_ADDR='http://0.0.0.0:8200'

vaultSecretPath=cluster1

crtName=tls.crt
keyName=tls.key
passName=jkspass
password=hello123

################################################

export VAULT_ADDR='http://0.0.0.0:8200'

vault login root

vault kv put secret/$vaultSecretPath $crtName="$(cat ca.crt)" $keyName="$(cat ca.key)" $passName="$password"

