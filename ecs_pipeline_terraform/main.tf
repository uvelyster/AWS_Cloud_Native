# provider 설정
provider "aws" {
  region = "ap-northeast-1" # 리전 변경
}


resource "aws_codedeploy_app" "demo_code_deploy_app" {
  name             = "demo_code_deploy_app"
  compute_platform = "ECS"
}


resource "aws_codebuild_project" "demo_code_maven_build" {
  name         = "demo_code_maven_build"
  service_role = aws_iam_role.code_build_service_role.arn
  description  = "Code build project to run the maven build and generate java artifacts"
  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    type         = "LINUX_CONTAINER"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
  }
}

resource "aws_codebuild_project" "demo_docker_build" {
  name         = "demo_docker_build"
  service_role = aws_iam_role.code_build_service_role.arn
  description  = "Code build project to generate the docker image."

  artifacts {
    type      = "CODEPIPELINE"
    packaging = "NONE"
    # location  = "s3://codepipeline-/test-2/"
    path      = "demo_docker_build"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "docker_buildspec.yml"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    type            = "LINUX_CONTAINER"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    privileged_mode = true
  }
}
resource "aws_codedeploy_deployment_group" "test_env_deploy_group" {
  deployment_group_name = "test_env_deploy_group"
  app_name              = aws_codedeploy_app.test_env_app.name
  service_role_arn      = aws_iam_role.demo_code_deployer_role.arn
  autoscaling_groups    = [aws_autoscaling_group.test_env_asg.name]
  deployment_style {
    deployment_type = "IN_PLACE"
  }
  load_balancer_info {
    target_group_info {
      name = aws_alb.test_env_alb.name
    }
  }
}

resource "aws_codedeploy_deployment_group" "demo_code_deploy_group" {
  app_name               = aws_codedeploy_app.demo_code_deploy_app.name
  deployment_group_name  = "demo_code_deploy_group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.demo_code_deployer_role.arn
  ecs_service {
    service_name = aws_ecs_service.demo_ecs_service.name
    cluster_name = aws_ecs_cluster.demo_ecs_cluster.name
  }
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      termination_wait_time_in_minutes = 5
      action                           = "TERMINATE"
    }
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_alb_listener.demo_alb_listner.arn]
      }
      target_group {
        name = aws_alb_target_group.blue-alb-target-group.name
      }
      target_group {
        name = aws_alb_target_group.green-alb-target-group.name
      }
    }
  }
}
resource "aws_iam_role" "test_env_deploy_agent_role" {
  name               = "test_env_deploy_agent_role"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ec2.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

//IAM policy to provide access to S3
resource "aws_iam_policy" "test_env_deploy_policy" {
  name   = "test-env-deploy-policy"
  policy = file("code-deploy-policy.json")
}

//IAM EC2 Role and S3 Policy association
resource "aws_iam_policy_attachment" "test_env_deploy_policy_attach" {
  name       = "chapter-11-deploy-policy-attach"
  policy_arn = aws_iam_policy.test_env_deploy_policy.arn
  roles      = [aws_iam_role.test_env_deploy_agent_role.name]
}

resource "aws_codedeploy_app" "test_env_app" {
  compute_platform = "Server"
  name             = "test_env_app"
}


output "test_elb_dns_name" {
  value = aws_alb.test_env_alb.dns_name
}
output "demo_elb_dns_name" {
  value = aws_alb.demo_alb.dns_name
}