provider "aws" {
  region = "ap-northeast-1"
}
resource "aws_iam_policy" "code_build_policy" {
  name   = "code-build-policy"
  policy = file("eks-role-policy.json")
}

// IAM role used by the code build service to get information from ECR and deploy to EKS. 
resource "aws_iam_role" "codebuild_eks_role" {
  name               = "codebuild-eks-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  //Managed Code Deploy service policy
  managed_policy_arns = [aws_iam_policy.code_build_policy.arn, "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess", "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess", "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess", "arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"]
}


resource "aws_codebuild_project" "code_build" {
  name         = "code-build"
  service_role = aws_iam_role.codebuild_eks_role.arn
  description  = "Code build project to run the maven build, create docker image, and deploy to EKS"
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
    privileged_mode = true
  }
}

// AWS Code build project to test the deployed application. 
resource "aws_codebuild_project" "test_application" {
  name         = "test-application"
  service_role = aws_iam_role.codebuild_eks_role.arn
  description  = "Code build project to run the shell script to test the application."
  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "test_stage.yml"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    type         = "LINUX_CONTAINER"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
  }
}