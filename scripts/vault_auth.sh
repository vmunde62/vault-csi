vault write auth/${params.cluster}/config \
    token_reviewer_jwt="${env.TOKEN_REVIEW_JWT}" \
    kubernetes_host="${env.KUBE_HOST}" \
    kubernetes_ca_cert="${env.KUBE_CA_CERT}" \
    issuer="https://kubernetes.default.svc.cluster.local"