#!/usr/bin/env bash

check_status()
{
if [ $? -ne 0 ]
then
  echo "Something went wrong, please check logs..."
  exit 1
fi
}

echo "locating kubectl binaries..."
[ -x /usr/local/bin/kubectl ] || { echo "[!] ERROR: Missing kubectl on this system. Aborting."; exit 1; }

CLUSTER_NAME=$(kubectl config view |grep current-context |awk '{print $2}')
echo "kubectl is pointing to: $CLUSTER_NAME"

echo "fetching the list of cluster nodes:"
kubectl get nodes
check_status

