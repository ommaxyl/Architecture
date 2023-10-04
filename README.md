# simpletf
Simple demonstration of Terraform

First setup the required IAM Role
In the console, IAM, "Create Role" and create a role as ecsTaskExecutionRole and
attach the policy AmazonECSTaskExecutionRolePolicy.

To test in place, you can use 'docker compose up' and then
curl http://localhost:5050. *NOTE: running on port 5050 externally
while running on default Flask port 5000 in the container due to a conflict
specific to MacOS and the AirPlay receiver port.

Then the command cmflask.sh runs everything.
