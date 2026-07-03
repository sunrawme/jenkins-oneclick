output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "The public IP of the Bastion Jump Box used by Jenkins/Ansible"
}
