
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

resource "aws_iam_role" "code_deployer_role" {
    name                = "code_deployer_role"
    assume_role_policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "codedeploy.amazonaws.com"
               },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    //Managed Code Deploy service policy
    managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"]
}
