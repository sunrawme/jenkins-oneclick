output "sonarqube_alb_url" {
  value       = "http://${aws_lb.sonar_alb.dns_name}"
  description = "The public web address to access your SonarQube dashboard load balancer."
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip # Make sure the resource name matches yours
}

output "sonar_active_private_ip" {
  # This retrieves the private IP of the instance created by your ASG
  value = element(flatten(aws_autoscaling_group.sonar_asg_az1.*.instances), 0)
}

output "sonar_passive_private_ip" {
  value = element(flatten(aws_autoscaling_group.sonar_asg_az2.*.instances), 0)
}
