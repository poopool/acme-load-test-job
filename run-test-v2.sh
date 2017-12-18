#!/usr/bin/env bash

#!/usr/bin/env bash

check_status()
{
    if [ $? -ne 0 ]
    then
      echo "Something went wrong, please check logs..."
      exit 1
    fi
}

run_test()
{

    echo "starting ephemeral container to run tests inside it..."
    kubectl run exec-test -n $namespace --image=nginx
    check_status
    sleep 5

    EXEC_TEST_POD=$(kubectl -n $namespace get po |grep exec-test|awk '{print $1}')
    echo "installing apache benchmark tool..."
    kubectl -n $namespace exec -it $EXEC_TEST_POD -- bash -c "apt-get -qq update && apt-get -qq install -y procps apache2-utils wget curl zip"
    echo "creating post file in remote container"
    kubectl -n $namespace exec -it $EXEC_TEST_POD -- bash -c "echo $post_payload > /post.file"

    c=$cuncurrent_connections
    n=$total_connections
    echo "Running ab -k -c $c -n $n -T application/x-www-form-urlencoded -k -p post.file $end_point &>test-$counter.txt"
    kubectl -n $namespace exec -it $EXEC_TEST_POD -- bash -c "ab -k -c $c -n $n -T application/x-www-form-urlencoded -p post.file $end_point &>test-result.txt"
    sleep 1
    echo "Test completed, analyzing the the result..."

    result=$(kubectl -n $namespace exec -it $EXEC_TEST_POD -- bash -c "cat test-result.txt |grep 95% > /dev/null ; echo $?")
    if [ $result -ne 0 ]
    then
      echo "Test failed, aborting..."
      resturn 1
    else
      echo "Test was successful, saving average response time for 95% of requests:"
      final_result=$(kubectl -n $namespace exec -it $EXEC_TEST_POD -- bash -c "cat test-result.txt |grep 95%")
    fi

    echo "killing ephemeral container"
    kubectl -n $namespace delete deploy exec-test
    sleep 5

}

cuncurrent_connections=$1
total_connections=$2
end_point=$3
post_payload=$4
namespace=$5

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

run_test

echo "Final result..."
echo $final_result |awk {'print $2'}
