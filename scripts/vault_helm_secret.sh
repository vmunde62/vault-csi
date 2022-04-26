kubectl get secrets --output=json | jq -r '.items[].metadata | select(.name|startswith("vault-token-")).name'
