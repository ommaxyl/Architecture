#!/bin/bash

# Abdullahi's Critical Mass simple Flask/Docker/Fargate/Terraform submission


# move into the base directory in case this is run from anywhere else
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

DOCKERIMAGE=abdullahi-cm-flask
REPONAME=abdullahi-cm-flask
AWSREGION=eu-west-2 # London region

AWSACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "Working under account $AWSACCOUNT"


# --- Docker Section ---

# build the docker image
cd python-api
docker buildx build --platform=linux/amd64 -t $DOCKERIMAGE .

if [[ $? -ne 0 ]] ; then
    echo "Failed to build Docker Image, ABORTING"
    exit 11
fi

cd ..

# IAM section
policy=$(cat << EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)

aws iam create-role --role-name "ecsTaskExecutionRole" --assume-role-policy-document "$policy"

aws iam attach-role-policy --role-name ecsTaskExecutionRole \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

# --- ECR Section ---

# create the repository ignoring error if already exists
aws ecr create-repository --repository-name $REPONAME --region $AWSREGION

# ignore the error if the repo already exists
status=$?
if [[ $status -ne 0 && status -ne 254 ]] ; then
    echo "Failed to create repository due to $status, ABORTING"
    exit 10
elif [[ $status -eq 254 ]] ; then
    echo "Repo already exists, CONTINUING"
else
    echo "Repostiory Created"
fi

# login to the repo
password=$(aws ecr get-login-password --region $AWSREGION)
echo $password | docker login --username AWS --password-stdin \
    $AWSACCOUNT.dkr.ecr.$AWSREGION.amazonaws.com/$REPONAME

# push image to ECS
docker tag $DOCKERIMAGE:latest \
    $AWSACCOUNT.dkr.ecr.$AWSREGION.amazonaws.com/$DOCKERIMAGE:latest

docker push $AWSACCOUNT.dkr.ecr.$AWSREGION.amazonaws.com/$DOCKERIMAGE:latest

# ---- Terraform Section ---
cd terraform

export TF_VAR_flask_app_image="${AWSACCOUNT}.dkr.ecr.${AWSREGION}.amazonaws.com/${DOCKERIMAGE}:latest"

terraform init
if [[ $? -ne 0 ]] ; then
    echo "Failed to initialize terraform, ABORTING"
    exit 12
fi

terraform validate
if [[ $? -ne 0 ]] ; then
    echo "Failed to validate terraform configuration, ABORTING"
    exit 13
fi

terraform plan
if [[ $? -ne 0 ]] ; then
    echo "Failed to plan terraform configuration, ABORTING"
    exit 14
fi

terraform apply -auto-approve
if [[ $? -ne 0 ]] ; then
    echo "Failed to apply terraform configuration, ABORTING"
    exit 14
fi

DNSENDPOINT=$(terraform output -raw alb-dns-name)

echo "Now sleeping for 2 minutes to allow the task to come up"
sleep 120
echo "Continuing to test in curl, without jq this will be blind"

# --- curl test section ---
curl $DNSENDPOINT:5000/
curl $DNSENDPOINT:5000/2
curl -X POST $DNSENDPOINT:5000
