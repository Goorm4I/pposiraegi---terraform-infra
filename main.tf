provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

############################
# Data: AZ
############################
data "aws_availability_zones" "available" {}

############################
# VPC
############################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

############################
# IGW
############################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

############################
# Subnets
############################

# ALB용 Public 서브넷 (2개 AZ 필수)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-b" }
}

# Bastion용 Public 서브넷
resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_c
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-c" }
}

# NAT Gateway용 Public 서브넷 (현재 비활성)
resource "aws_subnet" "public_d" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_d
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-d" }
}

# Backend EC2 Private 서브넷
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "${var.project_name}-private-a" }
}

# RDS / Redis Multi-AZ용 Private 서브넷
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_b
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "${var.project_name}-private-b" }
}

############################
# Route Tables
############################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_d" {
  subnet_id      = aws_subnet.public_d.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

############################
# Security Groups
############################

# CloudFront IP 대역만 ALB 접근 허용 (직접 접근 차단)
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group - CloudFront only"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_security_group" "bastion_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion security group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-bastion-sg" }
}

resource "aws_security_group" "app_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.project_name}-app-sg"
  description = "Backend app security group"

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

resource "aws_security_group" "rds_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.project_name}-rds-sg"
  description = "RDS security group"

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

resource "aws_security_group" "redis_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.project_name}-redis-sg"
  description = "Redis security group"

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-redis-sg" }
}

############################
# Key Pair
############################

resource "aws_key_pair" "main_key" {
  key_name   = var.key_name
  public_key = file(var.ssh_public_key_path)
}

############################
# S3 (프론트엔드 정적 호스팅)
############################

resource "aws_s3_bucket" "frontend" {
  bucket        = var.frontend_bucket_name
  force_destroy = true

  tags = { Name = "${var.project_name}-frontend" }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document { suffix = "index.html" }
  error_document { key    = "index.html" }
}

############################
# CloudFront OAC
############################

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

############################
# ACM Certificate (CloudFront용 - us-east-1 고정)
############################

resource "aws_acm_certificate" "cert" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project_name}-cert" }
}

############################
# Route 53 호스팅 존
############################

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = { Name = "${var.project_name}-zone" }
}

############################
# ACM DNS 검증 레코드
############################

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
    if dvo.domain_name == var.domain_name
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

############################
# EC2
############################

# Bastion: Public 서브넷, SSH 접근용
resource "aws_instance" "bastion" {
  ami                         = var.ec2_ami
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public_c.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.main_key.key_name

  tags = { Name = "${var.project_name}-bastion" }
}

# Backend: Private 서브넷, docker-compose로 앱 자동 실행
resource "aws_instance" "backend" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = aws_key_pair.main_key.key_name

  user_data = templatefile("${path.module}/user_data.sh", {
    github_repo          = var.github_repo
    jwt_secret           = var.jwt_secret
    cors_allowed_origins = "https://${var.domain_name}"
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.project_name}-backend" }
}

############################
# ALB
############################

resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.project_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/v3/api-docs"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-499"
  }

  tags = { Name = "${var.project_name}-tg" }
}

resource "aws_lb_target_group_attachment" "backend" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.backend.id
  port             = var.app_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

############################
# CloudFront Distribution
############################

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200"
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  # S3 Origin (프론트엔드)
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # ALB Origin (백엔드 API)
  origin {
    domain_name = aws_lb.alb.dns_name
    origin_id   = "alb-backend"

    # CloudFront → ALB 요청에 커스텀 헤더 추가 (직접 접근 차단용)
    custom_header {
      name  = "X-CloudFront-Secret"
      value = var.cloudfront_secret
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # /* → S3 (프론트엔드 정적 파일)
  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  # /api/* → ALB (백엔드 API)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "alb-backend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Origin", "Content-Type", "Accept"]
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # SPA 라우팅: 403/404 → index.html
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Name = "${var.project_name}-cf" }
}

############################
# S3 Bucket Policy (CloudFront OAC 접근 허용)
############################

data "aws_iam_policy_document" "frontend_s3_policy" {
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_s3_policy.json
}

############################
# Route 53 → CloudFront Alias 레코드
############################

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

############################
# RDS
############################

resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = { Name = "${var.project_name}-rds-subnet-group" }
}

resource "aws_db_instance" "db" {
  engine                 = "postgres"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  multi_az               = false  # 개발 단계 비용 절감용 — 운영 배포 시 true로 변경
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  tags = { Name = "${var.project_name}-rds" }
}

############################
# ElastiCache Redis
############################

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis_sg.id]

  tags = { Name = "${var.project_name}-redis" }
}

############################################################
# NAT Gateway (현재 비활성 - 필요 시 주석 해제)
############################################################

# resource "aws_eip" "nat_eip" {
#   domain = "vpc"
# }

# resource "aws_nat_gateway" "nat" {
#   allocation_id = aws_eip.nat_eip.id
#   subnet_id     = aws_subnet.public_d.id
# }

# resource "aws_route" "private_nat" {
#   route_table_id         = aws_route_table.private_rt.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.nat.id
# }
