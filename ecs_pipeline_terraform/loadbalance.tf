
// IAM instance profile to attache the code deploy agent role
resource "aws_iam_instance_profile" "test_env_instance_profile" {
  name = "test_env_deploy_instance_profile"
  role = aws_iam_role.test_env_deploy_agent_role.name
}

// EC2 Auto scalling Group 
resource "aws_autoscaling_group" "test_env_asg" {
  name               = "test_asg"
  min_size           = 1
  max_size           = 2
  desired_capacity   = 2
  vpc_zone_identifier = [aws_subnet.my_subnet_a.id, aws_subnet.my_subnet_c.id]
  launch_template {
    id      = aws_launch_template.test_env_ec2_launch_template.id
    version = "$Latest"
  }
  health_check_type = "ELB"
}

//EC2 Launch template to create EC2 instances , change Image ID and key name 
resource "aws_launch_template" "test_env_ec2_launch_template" {
  name_prefix   = "my-launch-template"
  instance_type = "t2.micro"
  image_id      = "ami-0ab3794db9457b60a"
  key_name      = "deploy-demo-keypair"
    iam_instance_profile {
    name = aws_iam_instance_profile.test_env_instance_profile.name
  }
  vpc_security_group_ids = [aws_security_group.elb_sg.id]
  user_data            = filebase64("user_data.sh")
}

// EC2 Load Balancer 
resource "aws_alb" "test_env_alb" {
  name               = "test-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets          = [aws_subnet.my_subnet_a.id, aws_subnet.my_subnet_c.id]
}

resource "aws_alb" "demo_alb" {
  name               = "demo-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets          = [aws_subnet.my_subnet_a.id, aws_subnet.my_subnet_c.id]
}
//Application Load Balancer listener to connect on port 80
resource "aws_alb_listener" "test_env_alb_listner" {
  load_balancer_arn = aws_alb.test_env_alb.arn
  port              = 80
  default_action {
    target_group_arn = aws_alb_target_group.test_env_alb_target_group.arn
    type             = "forward"
  }
}
resource "aws_alb_listener" "demo_alb_listner" {
  load_balancer_arn = aws_alb.demo_alb.arn
  port              = 80
  default_action {
    target_group_arn = aws_alb_target_group.blue-alb-target-group.arn
    type             = "forward"
  }
}

// Aapplication load balancer target group , to detect EC2 instances running on port 80
resource "aws_alb_target_group" "test_env_alb_target_group" {
  port        = 80
  target_type = "instance"
  vpc_id      = aws_vpc.my_vpc.id
  name        = "test-alb-target-group"
  protocol    = "HTTP"
  health_check {
    protocol = "HTTP"
    path     = "/"
  }
}

resource "aws_alb_target_group" "blue-alb-target-group" {
  name = "blue-alb-target-group"
  port = 80
  target_type = "ip"
  protocol = "HTTP"
  vpc_id = aws_vpc.my_vpc.id
  health_check {
    path = "/"
    protocol = "HTTP"
  }
}
resource "aws_alb_target_group" "green-alb-target-group" {
  name = "green-alb-target-group"
  port = 80
  target_type = "ip"
  protocol = "HTTP"
  vpc_id = aws_vpc.my_vpc.id
  health_check {
    path = "/"
    protocol = "HTTP"
  }
}
