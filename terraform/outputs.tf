output "public_ip" {
  value = aws_instance.jenkins_host.public_ip
}

output "private_key_path" {
  value       = local_file.private_key.filename
  description = "Local path where Terraform saved the private key"
}








