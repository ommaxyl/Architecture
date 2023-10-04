# simpletf
Simple demonstration of Terraform

To test in place, you can use 'docker compose up' and then
curl http://localhost:5050. *NOTE: running on port 5050 externally
while running on default Flask port 5000 in the container due to a conflict
specific to MacOS and the AirPlay receiver port.

Required IAM ecsTaskExecutionRole is created by the bash script below. This
is a one-time action and straightforward in AWS CLI.

Then the command cmflask.sh runs everything.
