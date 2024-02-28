# provider 설정
provider "aws" {
  region = "ap-northeast-2" # 변경된 리전
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
  image_id      = "ami-04599ab1182cd7961" # ubuntu AMI
  instance_type = "t2.micro" # 인스턴스 타입 설정
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  key_name      = "demo-key"
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
  max_size = 10
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}

