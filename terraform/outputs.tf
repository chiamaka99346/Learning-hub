output "public_ip" {
  value       = aws_instance.jenkins_ec2.public_ip
  description = "Public IP of the EC2 instance"
}

output "jenkins_url" {
  value       = "http://${aws_instance.jenkins_ec2.public_dns}:${var.jenkins_http_port}"
  description = "URL to access Jenkins"
}


