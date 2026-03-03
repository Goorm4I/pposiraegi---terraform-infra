############################################
# General
############################################

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

############################################
# EC2
############################################

variable "ec2_ami" {
  description = "EC2 AMI ID"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
}

variable "my_ip" {
  description = "Your public IP for Bastion SSH access"
  type        = string
}

############################################
# Application
############################################

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8080
}

############################################
# RDS
############################################

variable "db_username" {
  description = "RDS master username"
  type        = string
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}
