import subprocess
import json
import time
import os

# Get the script directory
script_dir = subprocess.check_output(["dirname", __file__], universal_newlines=True).strip()

# Move into the base directory
os.chdir(script_dir)

DOCKERIMAGE = "muheez-cm-flask"
REPONAME = "muheez-cm-flask"
AWSREGION = "us-east-1"  # US-region

# Get AWS account using the 'jq' command-line tool
aws_account_cmd = "aws sts get-caller-identity | jq -r .Account"
aws_account_output = subprocess.check_output(aws_account_cmd, shell=True, universal_newlines=True)

if aws_account_output.strip():  # Check if there's a non-empty output
    aws_account = aws_account_output.strip()
    print(f"Working under account {aws_account}")
else:
    print("Failed to get AWS account.")
    exit(1)


# --- Docker Section ---

# Build the Docker image
docker_build_cmd = f"docker build -t {DOCKERIMAGE} ./python-api"
if subprocess.call(docker_build_cmd, shell=True) != 0:
    print("Failed to build Docker Image, ABORTING")
    exit(11)

# IAM section
policy = {
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

# Create ECS task execution role
create_role_cmd = "aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document"
create_role_cmd += f" '{json.dumps(policy)}'"
subprocess.call(create_role_cmd, shell=True)

# Attach AmazonECSTaskExecutionRolePolicy to the role
attach_policy_cmd = "aws iam attach-role-policy --role-name ecsTaskExecutionRole"
attach_policy_cmd += " --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
subprocess.call(attach_policy_cmd, shell=True)

# --- ECR Section ---

# Create the ECR repository ignoring error if already exists
create_repo_cmd = f"aws ecr create-repository --repository-name {REPONAME} --region {AWSREGION}"
subprocess.call(create_repo_cmd, shell=True)

# Ignore the error if the repo already exists
status = subprocess.call(create_repo_cmd, shell=True)
if status != 0 and status != 254:
    print(f"Failed to create repository due to {status}, ABORTING")
    exit(10)
elif status == 254:
    print("Repo already exists, CONTINUING")
else:
    print("Repository Created")

# Login to the repo
login_cmd = f"aws ecr get-login-password --region {AWSREGION} | docker login --username AWS"
login_cmd += f" --password-stdin {aws_account}.dkr.ecr.{AWSREGION}.amazonaws.com/{REPONAME}"
password = subprocess.check_output(login_cmd, shell=True, universal_newlines=True)

# Push image to ECR
docker_tag_cmd = f"docker tag {DOCKERIMAGE}:latest"
docker_tag_cmd += f" {aws_account}.dkr.ecr.{AWSREGION}.amazonaws.com/{DOCKERIMAGE}:latest"
subprocess.call(docker_tag_cmd, shell=True)

docker_push_cmd = f"docker push {aws_account}.dkr.ecr.{AWSREGION}.amazonaws.com/{DOCKERIMAGE}:latest"
subprocess.call(docker_push_cmd, shell=True)

# ---- Terraform Section ---
os.chdir("terraform")

# Set environment variable
os.environ["TF_VAR_flask_app_image"] = f"{aws_account}.dkr.ecr.{AWSREGION}.amazonaws.com/{DOCKERIMAGE}:latest"

# Initialize Terraform
terraform_init_cmd = "terraform init"
if subprocess.call(terraform_init_cmd, shell=True) != 0:
    print("Failed to initialize terraform, ABORTING")
    exit(12)

# Validate Terraform configuration
terraform_validate_cmd = "terraform validate"
if subprocess.call(terraform_validate_cmd, shell=True) != 0:
    print("Failed to validate terraform configuration, ABORTING")
    exit(13)

# Plan Terraform configuration
terraform_plan_cmd = "terraform plan"
if subprocess.call(terraform_plan_cmd, shell=True) != 0:
    print("Failed to plan terraform configuration, ABORTING")
    exit(14)

# Apply Terraform configuration
terraform_apply_cmd = "terraform apply -auto-approve"
if subprocess.call(terraform_apply_cmd, shell=True) != 0:
    print("Failed to apply terraform configuration, ABORTING")
    exit(14)

# Get the DNS endpoint
dns_endpoint = subprocess.check_output("terraform output -raw alb-dns-name", shell=True, universal_newlines=True)

print("Now sleeping for 2 minutes to allow the task to come up")
time.sleep(120)
print("Continuing to test in curl, without jq this will be blind")

# --- curl test section ---
curl_test_cmds = [
    f"curl {dns_endpoint}:5000/",
    f"curl {dns_endpoint}:5000/2",
    f"curl -X POST {dns_endpoint}:5000"
]

for cmd in curl_test_cmds:
    subprocess.call(cmd, shell=True)
