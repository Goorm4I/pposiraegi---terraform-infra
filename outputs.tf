output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = aws_lb.app_alb.dns_name
}

output "bastion_public_ip" {
  description = "Bastion Public IP"
  value       = aws_instance.bastion.public_ip
}

output "rds_endpoint" {
  description = "RDS Endpoint"
  value       = aws_db_instance.main.address
}
