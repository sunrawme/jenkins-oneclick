output "bastion_private_ip" {
  description = "The private IP address of the Bastion host"
  value       = aws_instance.bastion.private_ip
}

output "sonar_node_ips" {
  description = "Note: Nodes are managed by ASG, their private IPs can be fetched via AWS CLI if needed"
  value       = "Dynamic via ASG"
}
