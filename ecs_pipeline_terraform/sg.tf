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
  ingress {
    from_port   = 8080
    to_port     = 8080
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
    from_port    =  8080
    to_port      =  8080
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