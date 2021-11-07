#!/bin/bash

while getopts ":hr" opt; do
  case ${opt} in
    h ) # process option h
	echo "help"
      ;;
    r ) # process option t
	REGIONS="$2"
      ;;
    \? ) echo "Usage: cmd [-h] [-r]"
      ;;
  esac
done


export AWS_ROLE_ARN=""
export CLUSTER_NAME=""
export SERVICE_NAME=""

if [ -z "$REGIONS" ] ; then
	export REGIONS=("us-east-1" "us-east-2" "us-west-2" "ca-central-1" "eu-west-1" "eu-west-2" )
fi

export AWS_DEFAULT_REGION="us-east-1"

export CREDS=`aws --output=json sts assume-role --role-arn ${AWS_ROLE_ARN} --role-session-name jenkins`
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r .Credentials.SessionToken)


# loop through regions
for region in ${REGIONS[@]};
do
	export AWS_DEFAULT_REGION=$region
	declare CLUSTER_NAMES=`aws ecs list-clusters --output text --region=${region} | grep "-ecs-" | awk '{print $2}'`
	for cluster in ${CLUSTER_NAMES[@]};
	do
		for service in $(aws ecs list-services --cluster ${cluster} --output text --region=${region} | grep "sam"| awk '{print $2}')
		do
			for task in $(aws ecs list-tasks --cluster ${cluster} --service-name ${service} --output text --region=${region}| awk '{print $2}')
			do
				echo stopping task ${task}
				aws --output=json ecs stop-task --cluster ${cluster} --task $task
				aws --output=json ecs wait services-stable --cluster ${cluster} --services ${service}
			done
		done
	done
done
