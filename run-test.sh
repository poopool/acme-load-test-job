#!/usr/bin/env bash

check_status()
{
    if [ $? -ne 0 ]
    then
      echo "Something went wrong, please check logs..."
      exit 1
    fi
}

node_status()
{
    NODE_STATUS=$(kubectl get po | grep node |awk '{print $3}')
    NODE_POD_NAME=$(kubectl get po | grep node |awk '{print $1}')

    echo "Node.js status: $NODE_STATUS"
    sleep 1
    if [ $NODE_STATUS != "Running" ]
    then
      while [ $NODE_STATUS != "Running" ]
      do
        echo "waiting for Node.js status to change to \"Running\""
        sleep 5
        NODE_STATUS=$(kubectl get po | grep node |awk '{print $3}')
      done
    fi
}

mongo_status()
{
    MONGO_STATUS=$(kubectl get po | grep mongo |awk '{print $3}')
    MONGO_POD_NAME=$(kubectl get po | grep mongo |awk '{print $1}')

    echo "MongoDB status: $MONGO_STATUS"
    sleep 1
    if [ $MONGO_STATUS != "Running" ]
    then
      while [ $MONGO_STATUS != "Running" ]
      do
        echo "waiting for MongoDB status to change to \"Running\""
        sleep 5
        MONGO_STATUS=$(kubectl get po | grep mongo |awk '{print $3}')
      done
    fi
}

get_node_ext-ip()
{
    NODE_EXT_IP=$(kubectl get svc |grep node |awk '{print $3}')
    while [ $NODE_EXT_IP = "<pending>" ]
    do
        echo "waiting for node component public IP..."
        sleep 5
        NODE_EXT_IP=$(kubectl get svc |grep node |awk '{print $3}')
    done
}

run_test()
{
    IFS=$'\n'
    for next in `cat resource.txt`
    do
        req_cpu=$(echo $next |awk -F "," {'print $1'})
        req_cpu+=m
        req_mem=$(echo $next |awk -F "," {'print $2'})
        req_mem+=Mi
        limit_cpu=$(echo $next |awk -F "," {'print $3'})
        limit_cpu+=m
        limit_mem=$(echo $next |awk -F "," {'print $4'})
        limit_mem+=Mi
        pod_count=$(echo $next |awk -F "," {'print $5'})

        jq '.spec.template.spec.containers[].resources.requests.cpu = '$req_cpu'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json
        jq '.spec.template.spec.containers[].resources.requests.memory = '$req_mem'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json
        jq '.spec.template.spec.containers[].resources.limits.cpu = '$limit_cpu'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json
        jq '.spec.template.spec.containers[].resources.limits.memory = '$limit_mem'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json
        jq '.spec.replicas = '$pod_count'' acme-app/node-deploy.json |sponge acme-app/node-deploy.json

        kubectl apply -f acme-app/node-deploy.json
        check_status
        sleep 10

        echo "starting ephemeral container to run tests inside it..."
        kubectl run exec-test  --image=nginx --env="BB_API_KEY=$BB_API_KEY" --env="req_cpu=$req_cpu" --env="req_mem=$req_mem" --env="limit_cpu=$limit_cpu" --env="limit_mem=$limit_mem"
        check_status

        EXEC_TEST_POD=$(kubectl get po |grep exec-test|awk '{print $1}')

        counter=1
        IFS=$'\n'
        for next in `cat uni.txt`
        do
            c=$(echo $next |awk -F "," {'print $1'})
            n=$(echo $next |awk -F "," {'print $2'})
            kubectl exec -it $EXEC_TEST_POD -- bash -c "apt-get update && apt-get install -y apache2-utils wget curl zip"
            echo "Running ab -k -c $c -n $n -T application/x-www-form-urlencoded -k -p post.file $URL &>test-$counter.txt"
            kubectl exec -it $EXEC_TEST_POD -- bash -c "ab -k -c $c -n $n -T application/x-www-form-urlencoded -k -p post.file $URL &>test-$counter.txt"
            counter=$((counter+1))
        done

        kubectl exec -it $EXEC_TEST_POD -- bash -c "export OUT_PUT_FILE=results-$req_cpu-$req_mem-$limit_cpu-$limit_mem"
        kubectl exec -it $EXEC_TEST_POD -- bash -c "mkdir -p $OUT_PUT_FILE"
        kubectl exec -it $EXEC_TEST_POD -- bash -c "mv test-* $OUT_PUT_FILE"
        kubectl exec -it $EXEC_TEST_POD -- bash -c "zip -r $OUT_PUT_FILE.zip $OUT_PUT_FILE"

        echo "Uploading results to bitbucket storage"
        kubectl exec -it $EXEC_TEST_POD -- bash -c "curl --user applariat:$BB_API_KEY --form files=@"${OUT_PUT_FILE}" "https://api.bitbucket.org/2.0/repositories/applariat/apl-policy/downloads""
        echo "killing ephemeral container"
        kubectl delete deploy exec-test

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
[ -d acme-app/ ] || { echo "[!] ERROR: Missing acme-app dir. Aborting."; exit 1; }

echo "deploying acme-app..."
sleep 1
kubectl apply -f acme-app/
check_status

sleep 10

echo "checking acme-app running status..."
sleep 1
#
#MONGO_STATUS=$(kubectl get po | grep mongo |awk '{print $3}')
#MONGO_POD_NAME=$(kubectl get po | grep mongo |awk '{print $1}')
#
#echo "MongoDB status: $MONGO_STATUS"
#sleep 1
#if [ $MONGO_STATUS != "Running" ]
#then
#  while [ $MONGO_STATUS != "Running" ]
#  do
#    echo "waiting for MongoDB status to change to \"Running\""
#    sleep 5
#    MONGO_STATUS=$(kubectl get po | grep mongo |awk '{print $3}')
#  done
#fi

mongo_status

#NODE_STATUS=$(kubectl get po | grep node |awk '{print $3}')
#NODE_POD_NAME=$(kubectl get po | grep node |awk '{print $1}')
#
#echo "Node.js status: $NODE_STATUS"
#sleep 1
#if [ $NODE_STATUS != "Running" ]
#then
#  while [ $NODE_STATUS != "Running" ]
#  do
#    echo "waiting for Node.js status to change to \"Running\""
#    sleep 5
#    NODE_STATUS=$(kubectl get po | grep node |awk '{print $3}')
#  done
#fi

node_status

#NODE_EXT_IP=$(kubectl get svc |grep node |awk '{print $3}')
#while [ $NODE_EXT_IP = "<pending>" ]
#do
#    echo "waiting for node component public IP..."
#    sleep 5
#    NODE_EXT_IP=$(kubectl get svc |grep node |awk '{print $3}')
#done

get_node_ext-ip

echo "external_ip: $NODE_EXT_IP"
echo "checking connection to acme-air:3000"
sleep 5
CONN_STAT=$(nc -z $NODE_EXT_IP 3000; echo $?)
delay_counter=12
while [ $CONN_STAT -ne 0 ] || [ $delay_counter -ne 0 ]
do
    sleep 10
    delay_counter=$((delay_counter-1))
    CONN_STAT=$(nc -z $NODE_EXT_IP 3000; echo $?)
done

while [ $CONN_STAT -ne 0 ]
do
      echo "Something went wrong, acme-air app is not responding. Going to restart the pod..."
      kubectl delete pod $NODE_POD_NAME
      sleep 10
      node_status
      get_node_ext-ip
      CONN_STAT=$(nc -z $NODE_EXT_IP 3000; echo $?)
done

echo "acme-app is running, going to seed acme database..."
sleep 1
curl -H "Content-Type: application/x-www-form-urlencoded" -X GET http://$NODE_EXT_IP:3000/rest/api/loader/load?numCustomers=1000


echo "locating uni.txt file..."
sleep 1
[ -f uni.txt ] || { echo "[!] ERROR: Missing uni.txt. Aborting."; exit 1; }

echo "locating resource.txt file..."
sleep 1
[ -f resource.txt ] || { echo "[!] ERROR: Missing uni.txt. Aborting."; exit 1; }

run_test


