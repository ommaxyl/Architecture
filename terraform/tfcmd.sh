#!/bin/bash

if [[ $# -ne 1 ]] ; then
    echo "usage: $0 <terraform_command>"
    exit 10
fi

DOCKERIMAGE=abdullahi-cm-flask
AWSREGION=eu-west-2 # London region
AWSACCOUNT=$(aws sts get-caller-identity --query Account --output text)

export TF_VAR_flask_app_image="${AWSACCOUNT}.dkr.ecr.${AWSREGION}.amazonaws.com/${DOCKERIMAGE}:latest"

terraform $1 # -var "awsaccount=$AWSACCOUNT" -var "awsregion=$awsregion" -var "dockerimage=$DOCKERIMAGE"
