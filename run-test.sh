#!/usr/bin/env bash

check_status()
{
    if [ $? -ne 0 ]
    then
      echo "Something went wrong, please check logs..."
      exit 1
    fi
}

generate_deployment_file()
{
    mkdir .tmp
    IFS=$'\n'
    for next in `cat resource.txt`
    do
        req-cpu=$(echo $next |awk -F "," {'print $1'})
        req-cpu+=m
        req-mem=$(echo $next |awk -F "," {'print $2'})
        req-mem+=Mi
        limit-cpu=$(echo $next |awk -F "," {'print $3'})
        limit-cpu+=m
        limit-mem=$(echo $next |awk -F "," {'print $4'})
        limit-mem+=Mi
        pod-count=$(echo $next |awk -F "," {'print $5'})

        jq '.spec.template.spec.containers[].resources.requests.cpu = '$req-cpu'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json
        jq '.spec.template.spec.containers[].resources.requests.memory = '$req-mem'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json
        jq '.spec.template.spec.containers[].resources.limits.cpu = '$limit-cpu'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json
        jq '.spec.template.spec.containers[].resources.limits.memory = '$limit-mem'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json
        jq '.spec.replicas = '$pod-count'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json

        kubectl apply -f acme-app/node-deploy.json

        IFS=$'\n'
        for next in `cat uni.txt`
        do
            c=$(echo $next |awk -F "," {'print $1'})
            n=$(echo $next |awk -F "," {'print $2'})
            echo "Running ab -k -c $c -n $n -T application/x-www-form-urlencoded -k -p post.file $URL &>test-$counter.txt"
            ab -k -c $c -n $n -T application/x-www-form-urlencoded -k -p post.file $URL &>test-$counter.txt
            counter=$((counter+1))
        done

    done

}

echo "locating kubectl binaries..."
sleep 1
[ -x /usr/local/bin/kubectl ] || { echo "[!] ERROR: Missing kubectl on this system. Aborting."; exit 1; }

CLUSTER_NAME=$(kubectl config view |grep current-context |awk '{print $2}')
echo "kubectl is pointing to: $CLUSTER_NAME"
sleep 1

echo "fetching the list of cluster nodes:"
sleep 1
kubectl get nodes
check_status

echo "locating acme-app dir"
sleep 1
[ -d /usr/local/bin/kubectl ] || { echo "[!] ERROR: Missing acme-app dir. Aborting."; exit 1; }

echo "deploying acme-app..."
sleep 1
kubectl apply -f acme-app/
check_status

sleep 10

echo "checking acme-app running status..."
sleep 1

MONGO_STATUS=$(kubectl get po | grep mongo |awk '{print $3}')
MONGO_POD_NAME=$(kubectl get po | grep mongo |awk '{print $1}')

echo "MongoDB status: $MONGO_STATUS"
sleep 1
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
sleep 1
if [ $NODE_STATUS != "Running" ]
then
  while [ $NODE_STATUS != "Running" ]
  do
    echo "waiting for Node.js status to change to \"Running\""
    wait 5
  done
fi

echo "acme-app is running, going to seed acme database..."
sleep 1
kubectl exec -it $NODE_POD_NAME -- bash -c "curl -H \"Content-Type: application/x-www-form-urlencoded\" -X GET http://node:3000/rest/api/loader/load?numCustomers=1000"
check_status

echo "locating uni.txt file..."
sleep 1
[ -f uni.txt ] || { echo "[!] ERROR: Missing uni.txt. Aborting."; exit 1; }

echo "locating resource.txt file..."
sleep 1
[ -f resource.txt ] || { echo "[!] ERROR: Missing uni.txt. Aborting."; exit 1; }

generate_deployment_file


