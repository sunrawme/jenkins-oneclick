output "sonarqube_alb_url" {
  value       = "http://${aws_lb.sonar_alb.dns_name}"
  description = "The public web address to access your SonarQube dashboard load balancer."
}
