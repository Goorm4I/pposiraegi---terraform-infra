output "cloudfront_url" {
  description = "프론트엔드 접속 URL (CloudFront)"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "domain_url" {
  description = "커스텀 도메인 URL"
  value       = "https://${var.domain_name}"
}

output "alb_dns" {
  description = "백엔드 ALB DNS (내부 확인용)"
  value       = "http://${aws_lb.alb.dns_name}"
}

output "bastion_ip" {
  description = "Bastion EC2 퍼블릭 IP (SSH 접근용)"
  value       = aws_instance.bastion.public_ip
}

output "backend_private_ip" {
  description = "Backend EC2 프라이빗 IP"
  value       = aws_instance.backend.private_ip
}

output "rds_endpoint" {
  description = "RDS 엔드포인트 (Private 접근만 가능)"
  value       = aws_db_instance.db.endpoint
}

output "redis_endpoint" {
  description = "Redis 엔드포인트 (Private 접근만 가능)"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "s3_bucket_name" {
  description = "프론트엔드 S3 버킷명"
  value       = aws_s3_bucket.frontend.bucket
}

output "route53_nameservers" {
  description = "도메인 등록기관에 설정할 네임서버"
  value       = aws_route53_zone.main.name_servers
}

output "ssh_bastion_command" {
  description = "Bastion EC2 SSH 접속 명령어"
  value       = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_instance.bastion.public_ip}"
}

output "frontend_deploy_command" {
  description = "프론트엔드 S3 배포 명령어"
  value       = "aws s3 sync ./build s3://${aws_s3_bucket.frontend.bucket} --profile goorm --delete"
}
