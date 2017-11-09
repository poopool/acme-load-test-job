#!/bin/bash

#Mapping build vars to env vars
INPUT_FILE_NAME=${INPUT_FILE_NAME-uni.txt}
URL=${URL-http://node:3000/rest/api/login}
BB_API_KEY=${BB_API_KEY}

#Installing useful tools
apt-get update
apt-get install -y apache2-utils wget curl lsb-release zip


sleep 30

#Running tests...
counter=1

IFS=$'\n'
for next in `cat $INPUT_FILE_NAME`
do
    c=$(echo $next |awk -F "," {'print $1'})
    n=$(echo $next |awk -F "," {'print $2'})
    echo "ab -k -c $c -n $n -T application/x-www-form-urlencoded -k -p post.file $URL &>test-$counter.txt"
    ab -k -c $c -n $n -T application/x-www-form-urlencoded -k -p post.file $URL &>test-$counter.txt
    counter=$((counter+1))
done

echo "Ran all the test cases sucessfully...exiting"

mkdir -p results
mv test-* results/
OUTPUT_FILE_NAME=test-results-$(date +"%Y-%m-%d_%I-%M_%p").zip
zip -r $OUTPUT_FILE_NAME results/

echo "Uploading results to bitbucket storage"

echo Upload was successful
curl --verbose --user applariat:$BB_API_KEY \
			--form files=@"${OUTPUT_FILE_NAME}" \
			"https://api.bitbucket.org/2.0/repositories/applariat/apl-policy/downloads"


exit 0