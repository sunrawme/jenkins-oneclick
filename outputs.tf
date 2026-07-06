output "sonar_active_url" {
  value       = "http://${aws_instance.sonar_active.public_ip}:9000"
  description = "Primary SonarQube Dashboard URL"
}

output "sonar_passive_url" {
  value       = "http://${aws_instance.sonar_passive.public_ip}:9000"
  description = "Standby SonarQube Dashboard URL"
}
