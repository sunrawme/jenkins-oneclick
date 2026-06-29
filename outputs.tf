output "alb_dns_name" {
  value = aws_lb.sonar_alb.dns_name
}

output "sonar_node_private_ips" {
  value = aws_instance.sonar_nodes[*].private_ip
}

output "efs_dns_name" {
  value = aws_efs_file_system.sonar_shared.dns_name
}
