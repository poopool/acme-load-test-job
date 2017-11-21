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

echo "locating acme-app dir"
[ -d /usr/local/bin/kubectl ] || { echo "[!] ERROR: Missing acme-app dir. Aborting."; exit 1; }

echo "deploying acme-app..."
kubectl apply -f acme-app/
check_status

sleep 10

echo "checking acme-app running status..."

MONGO_STATUS=$(kubectl get po | grep mongo |awk '{print $3}')
MONGO_POD_NAME=$(kubectl get po | grep mongo |awk '{print $1}')

echo "MongoDB status: $MONGO_STATUS"
if [ $MONGO_STATUS != "Running" ]
then
  while [ $MONGO_STATUS != "Running" ]
  do
    echo "waiting for MongoDB status to change to \"Running\""
    wait 5
  done
fi

NODE_STATUS=$(kubectl get po | grep node |awk '{print $3}')
NODE_POD_NAME=$(kubectl get po | grep node |awk '{print $1}')

echo "Node.js status: $NODE_STATUS"
if [ $NODE_STATUS != "Running" ]
then
  while [ $NODE_STATUS != "Running" ]
  do
    echo "waiting for Node.js status to change to \"Running\""
    wait 5
  done
fi

echo "acme-app is running, going to seed acme database..."
kubectl exec -it $NODE_POD_NAME -- bash -c "curl -H \"Content-Type: application/x-www-form-urlencoded\" -X GET http://node:3000/rest/api/loader/load?numCustomers=1000"
check_status

sleep 5



