
resource "aws_iam_policy" "deploy_policy" {
  name   = "deploy-policy"
  policy = file("code-deploy-policy.json")
}

//IAM EC2 Role and S3 Policy association
resource "aws_iam_policy_attachment" "deploy_policy_attach" {
  name       = "deploy-policy-attach"
  policy_arn = aws_iam_policy.deploy_policy.arn
  roles      = [aws_iam_role.deploy_agent_role.name]
}

resource "aws_iam_role" "deploy_agent_role" {
  name               = "deploy_agent_role"
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

resource "aws_iam_role" "demo_code_deployer_role" {
  name = "code_deploy_service_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codedeploy.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2FullAccess", "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"]
}

resource "aws_iam_role" "code_build_service_role" {
  name = "code_build_service_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codebuild.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess", "arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds", "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"]
}


# IAM instance profile to attache the code deploy agent role
resource "aws_iam_instance_profile" "instance_profile" {
  name = "deploy_instance_profile"
  role = aws_iam_role.deploy_agent_role.name
}
