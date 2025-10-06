data "aws_ami" "al2023" {
  owners      = ["137112412989"] # Amazon
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "jenkins_host" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default_vpc_subnets.ids[0]
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  key_name               = aws_key_pair.jenkins.key_name
  associate_public_ip_address = true

  user_data = <<'BASH'
#!/usr/bin/env bash
set -euxo pipefail
# install docker and enable
dnf -y update || true
dnf -y install docker || yum -y install docker || curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker
BASH

  tags = { Name = "jenkins-prod" }
}