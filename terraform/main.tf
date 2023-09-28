provider "aws" {
  profile = "default"
  region = "eu-west-2"
}

/*

terraform/main.tf contains only resources strictly
related to deploying the application in ECS

*/

# create the ECS cluster
resource "aws_ecs_cluster" "fp-ecs-cluster" {
  name = "flask-app"

  tags = {
    Name = "flask-app"
  }
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# create and define the container task
resource "aws_ecs_task_definition" "fp-ecs-task" {
  family = "flask-app"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 512
  memory = 2048
  execution_role_arn = "${data.aws_iam_role.ecs_task_execution_role.arn}"
  container_definitions = <<DEFINITION
[
   {
      "name":"flask-app",
      "image":"${var.flask_app_image}",
      "essential":true,
      "portMappings":[
         {
            "containerPort":5000,
            "hostPort":5000,
            "protocol":"tcp"
         }
      ],
      "environment":[
         {
            "name":"FLASK_APP",
            "value":"${var.flask_app}"
         },
         {
            "name":"FLASK_ENV",
            "value":"${var.flask_env}"
         },
         {
            "name":"APP_HOME",
            "value":"${var.app_home}"
         },
         {
            "name":"APP_PORT",
            "value":"${var.flask_app_port}"
         }
      ]
   }
]
DEFINITION
}


resource "aws_ecs_service" "flask-service" {
  name = "flask-app-service"
  cluster = aws_ecs_cluster.fp-ecs-cluster.id
  task_definition = aws_ecs_task_definition.fp-ecs-task.arn
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.fp-ecs-sg.id]
    subnets = aws_subnet.fp-public-subnets.*.id
    assign_public_ip = true
  }

  load_balancer {
    container_name = "flask-app"
    container_port = var.flask_app_port
    target_group_arn = aws_alb_target_group.fp-target-group.id
  }

  depends_on = [
    aws_alb_listener.fp-alb-listener
  ]
}
