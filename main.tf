# provider 설정
provider "aws" {
  region = "ap-northeast-1" # 리전 변경
}

# VPC 생성
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16" # VPC CIDR 블록 설정

  tags = {
    Name = "terraform-vpc"
    managedby = "terraform"
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "terraform-igw"
    managedby = "terraform"
  }
}

# 라우팅 테이블 생성
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # 모든 트래픽을 IGW로 전달
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "terraform-rt"
    managedby = "terraform"
  }
}

# 서브넷 생성 - 가용 영역 A
resource "aws_subnet" "my_subnet_a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24" # 서브넷 CIDR 블록 설정
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "terraform-a"
    managedby = "terraform"
  }
}

# 서브넷 생성 - 가용 영역 C
resource "aws_subnet" "my_subnet_c" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24" # 서브넷 CIDR 블록 설정
  availability_zone = "ap-northeast-1c"
map_public_ip_on_launch = true
  tags = {
    Name = "terraform-c"
    managedby = "terraform"
  }
}

# 가용 영역 A의 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "my_route_table_association_a" {
  subnet_id      = aws_subnet.my_subnet_a.id
  route_table_id = aws_route_table.my_route_table.id
}

# 가용 영역 C의 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "my_route_table_association_c" {
  subnet_id      = aws_subnet.my_subnet_c.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_iam_policy" "deploy_policy" {
  name   = "deploy-policy"
  policy = file("code-deploy-policy.json")
}

resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "test_keypair" {
  key_name   = "deploy-demo-keypair"
  public_key = tls_private_key.test_key.public_key_openssh
} 

resource "local_file" "test_local" {
  filename        = "./keypair/deploy-demo-keypair.pem"
  content         = tls_private_key.test_key.private_key_pem
  file_permission = "0400"
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

# 인스턴스용 보안그룹
resource  "aws_security_group" "instance-sg"  {
  name  =  "terraform-example-instance-sg" 
  vpc_id = aws_vpc.my_vpc.id

  ingress  { 
    from_port    =  80
    to_port      =  80
    protocol     =  "tcp"
    cidr_blocks  =  [ "0.0.0.0/0" ] 
  }
  ingress  { 
    from_port    =  22
    to_port      =  22
    protocol     =  "tcp"
    cidr_blocks  =  [ "0.0.0.0/0" ] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM instance profile to attache the code deploy agent role
resource "aws_iam_instance_profile" "instance_profile" {
  name = "deploy_instance_profile"
  role = aws_iam_role.deploy_agent_role.name
}

# Launch Template 생성
resource "aws_launch_template" "my_launch_template" {
  name_prefix   = "my-launch-template"
  image_id      = "ami-0ab3794db9457b60a" # Amazonlinux2023
  instance_type = "t2.micro" # 인스턴스 타입 설정
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  key_name      = "deploy-demo-keypair"
  user_data = filebase64("user_data.sh")
  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }
  tags = {
    managedby = "terraform"
  }
}

# autoscaling group
resource "aws_autoscaling_group" "example" {
  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.my_subnet_a.id, aws_subnet.my_subnet_c.id]
  target_group_arns = [aws_lb_target_group.asg.arn]
  min_size = 1
  desired_capacity   = 2
  max_size = 3
  desired_capacity   = 2
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}


# 보안 그룹 생성
resource "aws_security_group" "elb_sg" {
  name        = "elb_sg"
  description = "Allow inbound traffic on port 80"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-sg"
    managedby = "terraform"
  }
}

resource "aws_lb" "example" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = [aws_subnet.my_subnet_a.id, aws_subnet.my_subnet_c.id]
  security_groups = [aws_security_group.elb_sg.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward" 
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  } 
}

resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.my_vpc.id
  health_check {
    path = "/"
    protocol = "HTTP"
  #   matcher = "200"
  #   interval = 15
  #   timeout = 3
  #   healthy_threshold = 2
  #   unhealthy_threshold = 2
  }
}

output "elb_dns_name" {
  value = aws_lb.example.dns_name
}
