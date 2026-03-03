############################################
# Provider
############################################
provider "aws" {
  region = var.region
}

############################################
# AZ Data
############################################
data "aws_availability_zones" "available" {}

############################################
# VPC
############################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "infra-vpc" }
}

############################################
# IGW (Internet Gateway)
############################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "infra-igw" }
}

############################################
# Subnets
# - Public 2개 (ALB, Bastion)
# - Private App 2개 (Backend EC2, RDS Subnet Group)
############################################

# Public Subnet A
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "public-a" }
}

# Public Subnet B
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = { Name = "public-b" }
}

# Private App Subnet A
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = "private-app-a" }
}

# Private App Subnet B
resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = { Name = "private-app-b" }
}

############################################
# Route Tables
# - Public RT: IGW로 0.0.0.0/0 라우팅
# - Private RT: NAT를 쓸 때만 0.0.0.0/0 라우팅 (현재는 주석 처리)
############################################

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "public-rt" }
}

# Public Route -> Internet
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Public RT Association
resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

############################################
# Key Pair
# - 로컬 public key 경로는 환경에 맞게 수정
############################################
resource "aws_key_pair" "main_key" {
  key_name   = "infra-key"
  public_key = file("C:/Users/gkthf/.ssh/id_rsa.pub")
}

############################################
# Security Groups
# - ALB SG: 80/443 외부 허용
# - Bastion SG: SSH를 내 ip만 허용
# - Backend SG: SSH는 Bastion만, App 포트는 ALB만
# - RDS SG: DB 포트는 Backend만
############################################

# ALB SG
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  # HTTP (필요 없을시 제거)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (인증서 붙이면 사용)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}

# Bastion SG (내 IP만 SSH 허용) - IP는 변수로 분리
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bastion-sg" }
}

# Backend SG
resource "aws_security_group" "backend_sg" {
  name   = "backend-sg"
  vpc_id = aws_vpc.main.id

  # SSH: Bastion에서만
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # App Port: ALB에서만 (여기서는 8080 기준)
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "backend-sg" }
}

# RDS SG (DB 포트는 Backend에서만)
resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = aws_vpc.main.id

  # MySQL 예시: 3306 (PostgreSQL이면 5432로 바꾸면 됨)
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg" }
}

############################################
# Bastion EC2 (Public A)
############################################
resource "aws_instance" "bastion" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type

  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.main_key.key_name

  tags = { Name = "bastion" }
}

############################################
# Backend EC2 (Private App A/B)
############################################
resource "aws_instance" "backend_a" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type

  subnet_id              = aws_subnet.private_app_a.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = aws_key_pair.main_key.key_name

  tags = { Name = "backend-a" }
}

resource "aws_instance" "backend_b" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type

  subnet_id              = aws_subnet.private_app_b.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = aws_key_pair.main_key.key_name

  tags = { Name = "backend-b" }
}

############################################
# ALB (Public Subnet 2개에 걸쳐 생성)
# - Target Group: Backend EC2 2대를 8080으로 등록
# - Listener: 80 -> Target Group
############################################

resource "aws_lb" "app_alb" {
  name               = "app-alb"
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  security_groups = [aws_security_group.alb_sg.id]

  tags = { Name = "app-alb" }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # 상태체크 경로는 앱에 맞게 수정해야 함
  health_check {
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
    matcher             = "200-399"
  }

  tags = { Name = "app-tg" }
}

resource "aws_lb_target_group_attachment" "backend_a_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.backend_a.id
  port             = var.app_port
}

resource "aws_lb_target_group_attachment" "backend_b_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.backend_b.id
  port             = var.app_port
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

############################################
# RDS (Multi-AZ)
############################################

resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds-subnet-group"

  subnet_ids = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]

  tags = { Name = "rds-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier           = "infra-rds"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.rds_instance_class
  allocated_storage    = 20
  storage_type         = "gp2"

  # DB username/password는 변수로 분리 (GitHub 안전)
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  multi_az            = true
  publicly_accessible = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "infra-rds" }
}

############################################################
# NAT Gateway (비용 발생 -> 현재 비활성, 필요할 때 주석 해제)
# - 프라이빗 EC2가 yum/apt, docker pull 같은 외부 통신이 필요하면 NAT가 필요
############################################################

# ############################
# # Elastic IP for NAT
# ############################
# resource "aws_eip" "nat_eip" {
#   domain = "vpc"
# }

# ############################
# # NAT Gateway (Public Subnet A에 생성)
# ############################
# resource "aws_nat_gateway" "nat" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.public_a.id
#
#   tags = { Name = "nat-gateway" }
# }

# ############################
# # Private Route Table
# ############################
# resource "aws_route_table" "private_rt" {
#   vpc_id = aws_vpc.main.id
#   tags   = { Name = "private-rt" }
# }

# ############################
# # Private Route -> NAT 연결
# ############################
# resource "aws_route" "private_nat_route" {
#   route_table_id         = aws_route_table.private_rt.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.nat.id
# }

# ############################
# # Private Subnet Route Table 연결
# ############################
# resource "aws_route_table_association" "private_app_a_assoc" {
#   subnet_id      = aws_subnet.private_app_a.id
#   route_table_id = aws_route_table.private_rt.id
# }
#
# resource "aws_route_table_association" "private_app_b_assoc" {
#   subnet_id      = aws_subnet.private_app_b.id
#   route_table_id = aws_route_table.private_rt.id
# }
