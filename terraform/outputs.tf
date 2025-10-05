output "jenkins_instance_public_ip" {
  description = "Public IP of Jenkins EC2 instance"
  value       = aws_instance.jenkins_ec2.public_ip
}

output "jenkins_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.jenkins_ec2.id
}

output "jenkins_security_group_id" {
  description = "Security Group ID for Jenkins"
  value       = aws_security_group.jenkins_sg.id
}









