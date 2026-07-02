# Output the Public IP of the Bastion Host (Our new entry point for Ansible)
output "bastion_public_ip" {
  description = "The public IP address of the Bastion host"
  value       = aws_instance.bastion.public_ip
}

# Output the DNS Name of our Application Load Balancer
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.sonar_alb.dns_name
}

# Output the Target Group ARN Suffixes for any external tracking scripts
output "target_group_az1_arn_suffix" {
  description = "The ARN suffix of Target Group 1 (AZ1)"
  value       = aws_lb_target_group.sonar_tg_az1.arn_suffix
}

output "target_group_az2_arn_suffix" {
  description = "The ARN suffix of Target Group 2 (AZ2)"
  value       = aws_lb_target_group.sonar_tg_az2.arn_suffix
}

