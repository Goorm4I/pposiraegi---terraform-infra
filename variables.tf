############################################
# AWS 기본 설정
############################################

variable "aws_profile" {
  description = "AWS CLI profile name"
  default     = "goorm"
}

variable "region" {
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  default     = "pposiraegi"
}

############################################
# VPC 네트워크 설정
############################################

variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "public_subnet_a" {
  description = "Public subnet A CIDR (ALB용)"
  default     = "10.0.1.0/24"
}

variable "public_subnet_b" {
  description = "Public subnet B CIDR (ALB용)"
  default     = "10.0.2.0/24"
}

variable "public_subnet_c" {
  description = "Public subnet C CIDR (Bastion용)"
  default     = "10.0.3.0/24"
}

variable "public_subnet_d" {
  description = "Public subnet D CIDR (NAT Gateway용, 현재 비활성)"
  default     = "10.0.4.0/24"
}

variable "private_subnet_a" {
  description = "Private subnet A CIDR (Backend EC2용)"
  default     = "10.0.11.0/24"
}

variable "private_subnet_b" {
  description = "Private subnet B CIDR (RDS / Redis Multi-AZ용)"
  default     = "10.0.12.0/24"
}

############################################
# EC2 설정
############################################

variable "ec2_ami" {
  description = "AMI for EC2 (Amazon Linux 2023, ap-northeast-2)"
  default     = "ami-0c9c942bd7bf113a2"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}

############################################
# SSH / Key 설정
############################################

variable "key_name" {
  description = "EC2 Key Pair name"
  default     = "pposiraegi-key"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  default     = "~/.ssh/id_ed25519.pub"
}

############################################
# 접근 제어
############################################

variable "my_ip" {
  description = "Your public IP for SSH access (CIDR 형식, 예: 1.2.3.4/32)"
}

############################################
# 앱 포트 설정
############################################

variable "app_port" {
  description = "Backend application port"
  default     = 8080
}

############################################
# RDS 설정
############################################

variable "db_port" {
  description = "Database port (PostgreSQL)"
  default     = 5432
}

variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "RDS master username"
  default     = "admin"
}

variable "db_password" {
  description = "RDS master password"
  sensitive   = true
}

############################################
# 도메인 설정
############################################

variable "domain_name" {
  description = "Route53에 등록된 도메인명 (예: pposiraegi.com)"
}

############################################
# S3 설정
############################################

variable "frontend_bucket_name" {
  description = "프론트엔드 S3 버킷명 (전역 유일)"
}

############################################
# 보안 설정
############################################

variable "cloudfront_secret" {
  description = "CloudFront → ALB 커스텀 헤더 시크릿 값"
  sensitive   = true
}

############################################
# 애플리케이션 설정
############################################

variable "github_repo" {
  description = "GitHub repo URL to clone on EC2"
  default     = "https://github.com/Goorm4I/pposiraegi-ecommerce.git"
}

variable "jwt_secret" {
  description = "JWT secret key for Spring Boot"
  sensitive   = true
}
