output "sonarqube_alb_url" {
  value       = "http://${aws_lb.sonar_alb.dns_name}"
  description = "The public web address to access your SonarQube dashboard load balancer."
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip # Make sure the resource name matches yours
}


