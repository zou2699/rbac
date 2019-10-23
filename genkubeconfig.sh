#!/bin/bash

KUBE_API_SERVER="https://10.6.64.131:6443"
CERT_DIR=${2:-"/etc/kubernetes/pki"}

kubectl config set-cluster default-cluster --server=${KUBE_API_SERVER} \
    --certificate-authority=${CERT_DIR}/ca.crt \
    --embed-certs=true \
    --kubeconfig=readonly.kubeconfig

kubectl config set-credentials devops \
    --certificate-authority=${CERT_DIR}/ca.crt \
    --embed-certs=true \
    --client-key=readonly-key.pem \
    --client-certificate=readonly.pem \
    --kubeconfig=readonly.kubeconfig

kubectl config set-context default-system --cluster=default-cluster \
    --user=devops \
    --kubeconfig=readonly.kubeconfig

kubectl config use-context default-system --kubeconfig=readonly.kubeconfig

