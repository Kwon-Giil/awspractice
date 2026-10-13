# 1. VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ==============VPC (Virtual Private Cloud)======================

# 2. 인터넷 게이트웨이(IGW) 생성 (외부 통로)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ===============Internet Gateway (IGW)==================

# 3. AWS 가용 영역(AZ) 목록 조회 데이터소스
data "aws_availability_zones" "available" {
  state = "available"
}

# ===============AWS 가용 영역(AZ) 목록 조회 데이터소스==================

# 4. 퍼블릭 서브넷 생성 (이중화: 2개 AZ 활용)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# 5. 퍼블릭 라우팅 테이블 생성 (모든 외부 트래픽 0.0.0.0/0을 IGW로 향하게 지정)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 6. 퍼블릭 서브넷과 라우팅 테이블 연결 (Association)
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ===============Public Subnets (멀티 AZ 이중화)==================

# 7. NAT Gateway용 탄력적 IP (EIP) 생성
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# ===============Elastic IP (EIP)==================

# 8. NAT Gateway 생성 (첫 번째 퍼블릭 서브넷에 배치)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.gw]
}

# ===============NAT Gateway==================

# 9. 프라이빗 서브넷 생성 (이중화: 2개 AZ 활용)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# ===============Private Subnets==================

# 10. 프라이빗 라우팅 테이블 생성 (외부로 나가는 트래픽을 NAT Gateway로 연결)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# ===============Public Route Table & Associations==================

# 11. 프라이빗 서브넷과 프라이빗 라우팅 테이블 연결 (Association)
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ===============Private Subnets & Route Tables / Associations==================

# 12. 퍼블릭 웹서버용 보안 그룹 (HTTP, SSH 허용)
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for public web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere (For lab purpose)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# 13. 프라이빗 내부 서버용 보안 그룹 (웹서버 보안 그룹으로부터의 접근만 허용)
resource "aws_security_group" "private_db_sg" {
  name        = "${var.project_name}-private-db-sg"
  description = "Security group for private DB/app servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from web security group"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Fixed reference from web to web_sg
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-private-db-sg"
  }
}

# ===============Security Groups==================

# [Part 11] EC2 Instances Configuration

# 1. AMI 데이터 소스 (가장 최신 Amazon Linux 2023 AMI 조회)
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# 2. 퍼블릭 서브넷에 배치할 웹서버 (Public Web Server)
resource "aws_instance" "public_web" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro" # 프리티어 대상, 비용 최소화

  # 앞서 만든 첫 번째 퍼블릭 서브넷 지정
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "project-public-web-server"
  }
}

# 3. 프라이빗 서브넷에 배치할 내부 서버 (Private App/DB Server)
resource "aws_instance" "private_app" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"

  # 앞서 만든 첫 번째 프라이빗 서브넷 지정
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.private_db_sg.id]

  # 프라이빗이므로 퍼블릭 IP 부여 안 함
  associate_public_ip_address = false

  tags = {
    Name = "project-private-app-server"
  }
}