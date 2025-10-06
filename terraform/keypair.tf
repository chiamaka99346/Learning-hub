locals {
  key_name = "jenkins-prod"
  key_dir  = "${path.module}/secrets"
}

resource "tls_private_key" "jenkins" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename        = "${local.key_dir}/${local.key_name}.pem"
  content         = tls_private_key.jenkins.private_key_pem
  file_permission = "0600"
}

resource "aws_key_pair" "jenkins" {
  key_name   = local.key_name
  public_key = tls_private_key.jenkins.public_key_openssh
}