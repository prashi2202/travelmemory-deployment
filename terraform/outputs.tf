output "load_balancer_dns" {
  value = aws_lb.app.dns_name
}

output "jump_public_ip" {
  value = aws_instance.jump.public_ip
}

output "app_a_private_ip" {
  value = aws_instance.app_a.private_ip
}

output "app_c_private_ip" {
  value = aws_instance.app_c.private_ip
}

output "database_private_ip" {
  value = aws_instance.database.private_ip
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}
