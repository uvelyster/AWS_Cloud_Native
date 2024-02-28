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
  availability_zone = "ap-northeast-2a"
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
  availability_zone = "ap-northeast-2c"
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
