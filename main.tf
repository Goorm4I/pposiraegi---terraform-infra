provider "aws" {
  region = "ap-northeast-2"
}

############################
# VPC
############################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "infra-vpc" }
}

############################
# IGW
############################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "infra-igw" }
}

############################
# AZ
############################

data "aws_availability_zones" "available" {}

############################
# Public Subnet (Bastion용)
############################

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "public-a" }
}

############################
# Private Subnet (Backend용)
############################

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = "private-a" }
}

############################
# Public Route Table
############################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

############################
# Key Pair
############################

resource "aws_key_pair" "main_key" {
  key_name   = "infra-key"
  public_key = file("C:/Users/gkthf/.ssh/id_rsa.pub")
}

############################
# Bastion SG (내 ip만 허용)
############################

resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["59.18.34.177/32"]  # 내 ip
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# Backend SG (SSH는 Bastion만)
############################

resource "aws_security_group" "backend_sg" {
  name   = "backend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# Bastion EC2
############################

resource "aws_instance" "bastion" {
  ami           = "ami-0c9c942bd7bf113a2"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.main_key.key_name

  tags = { Name = "bastion" }
}

############################
# Backend EC2 (Private)
############################

resource "aws_instance" "backend" {
  ami           = "ami-0c9c942bd7bf113a2"
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = aws_key_pair.main_key.key_name

  tags = { Name = "backend" }
}

############################################################
# NAT Gateway (현재 비활성 - 필요할 때 주석 해제)
############################################################

# # Elastic IP for NAT
# resource "aws_eip" "nat_eip" {
#   vpc = true
# }

# # Private Route Table
# resource "aws_route_table" "private_rt" {
#   vpc_id = aws_vpc.main.id
#
#   tags = {
#     Name = "private-rt"
#   }
# }

# # NAT Gateway (Public Subnet에 생성)
# resource "aws_nat_gateway" "nat" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.public_a.id
#
#   tags = {
#     Name = "nat-gateway"
#   }
# }

# # Private Route → NAT 연결
# resource "aws_route" "private_nat_route" {
#   route_table_id         = aws_route_table.private_rt.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.nat.id
# }

# # Private Subnet Route Table 연결
# resource "aws_route_table_association" "private_assoc" {
#   subnet_id      = aws_subnet.private_a.id
#   route_table_id = aws_route_table.private_rt.id
# }
