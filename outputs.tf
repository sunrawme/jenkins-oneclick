output "bastion_private_ip" {
  description = "The private IP address of the Bastion host"
  value       = aws_instance.bastion.private_ip
}
