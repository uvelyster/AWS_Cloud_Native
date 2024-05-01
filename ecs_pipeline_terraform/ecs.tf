variable "container_image_uri" {
  type        = string
  description = "Please provide ECR container image URI for deployment"
  default     = "469427049902.dkr.ecr.ap-northeast-1.amazonaws.com/demo-ecr-repo:aws-code-pipeline"
}


resource "aws_ecs_cluster" "demo_ecs_cluster" {
  name = "demo_ecs_cluster"
  tags = {
    resource-group = "demo"
  }
}
resource "aws_ecs_cluster_capacity_providers" "demo_ecs_capacity_providers" {
  cluster_name       = aws_ecs_cluster.demo_ecs_cluster.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    base              = 0
    weight            = 1
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "demo_task_definition" {
  family                   = "demo_task_definition"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 3072
  execution_role_arn       = "arn:aws:iam::469427049902:role/ecsTaskExecutionRole"
  container_definitions = jsonencode([
    {
      name      = "demo_aws_code_pipeline_container"
      image     = var.container_image_uri
      cpu       = 512
      memory    = 3072
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}
resource "aws_ecs_service" "demo_ecs_service" {
  name            = "demo_ecs_service"
  cluster         = aws_ecs_cluster.demo_ecs_cluster.id
  task_definition = aws_ecs_task_definition.demo_task_definition.arn
  desired_count   = 1
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    security_groups  = [aws_security_group.elb_sg.id]
    subnets          = [aws_subnet.my_subnet_a.id, aws_subnet.my_subnet_c.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.blue-alb-target-group.arn
    container_name   = "demo_aws_code_pipeline_container"
    container_port   = "80"
  }
}
