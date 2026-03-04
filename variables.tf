############################################
# AWS 기본 설정
############################################

# AWS 리전
variable "region" {
  description = "AWS region"
}

############################################
# VPC 네트워크 설정
############################################

# VPC CIDR
variable "vpc_cidr" {
  description = "VPC CIDR block"
}

############################################
# Public Subnets
############################################

# Public Subnet A
variable "public_subnet_a" {
  description = "Public subnet A CIDR"
}

# Public Subnet B
variable "public_subnet_b" {
  description = "Public subnet B CIDR"
}

# Public Subnet C
variable "public_subnet_c" {
  description = "Public subnet C CIDR"
}

# Public Subnet D
variable "public_subnet_d" {
  description = "Public subnet D CIDR"
}

############################################
# Private Subnets
############################################

# Private Subnet A
variable "private_subnet_a" {
  description = "Private subnet A CIDR"
}

# Private Subnet B
variable "private_subnet_b" {
  description = "Private subnet B CIDR"
}

############################################
# EC2 설정
############################################

# EC2 AMI
variable "ec2_ami" {
  description = "AMI for EC2 instances"
}

# EC2 Instance Type
variable "ec2_instance_type" {
  description = "EC2 instance type"
}

############################################
# SSH / Key 설정
############################################

# SSH public key 경로
variable "ssh_public_key_path" {
  description = "Path to SSH public key"
}

# AWS Key Pair 이름
variable "key_name" {
  description = "AWS key pair name"
}

############################################
# 접근 제어
############################################

# Bastion SSH 접근 허용 IP
variable "my_ip" {
  description = "Your public IP for SSH access"
}

############################################
# Application 설정
############################################

# Backend Application Port
variable "app_port" {
  description = "Application port"
}

############################################
# Database 설정
############################################

# DB Port
variable "db_port" {
  description = "Database port"
  default     = 3306
}

# RDS Instance Class
variable "db_instance_class" {
  description = "RDS instance class"
}

# RDS Username
variable "db_username" {
  description = "Database username"
}

# RDS Password
variable "db_password" {
  description = "Database password"
  sensitive   = true
}
