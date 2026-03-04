output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "backend_private_ip" {
  value = aws_instance.backend.private_ip
}

output "rds_endpoint" {
  value = aws_db_instance.db.endpoint
}
