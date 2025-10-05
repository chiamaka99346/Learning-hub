terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for Jenkins + Docker host
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH, Jenkins, and Docker communication"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins Agent"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# User data for Jenkins + Docker setup
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Update system and install Java
    yum update -y
    amazon-linux-extras install -y java-openjdk17

    # Install Jenkins
    rpm --import https://pkg.jenkins.io/redhat/jenkins.io-2023.key
    cat >/etc/yum.repos.d/jenkins.repo <<'REPO'
    [jenkins]
    name=Jenkins-stable
    baseurl=https://pkg.jenkins.io/redhat-stable
    gpgcheck=1
    gpgkey=https://pkg.jenkins.io/redhat/jenkins.io-2023.key
    REPO

    yum install -y jenkins git docker

    # Enable and start services
    systemctl enable jenkins
    systemctl enable docker
    systemctl start docker
    systemctl start jenkins

    # Add Jenkins user to Docker group
    usermod -aG docker jenkins
    systemctl restart jenkins

    # Optional editors
    if [ "${var.install_editors}" = "true" ]; then
      yum install -y vim-enhanced nano || true
    fi

    # Clone repo if provided
    if [ -n "${var.github_repo_url}" ]; then
      mkdir -p ${var.repo_clone_path}
      cd ${var.repo_clone_path}
      git clone -b ${var.github_repo_branch} ${var.github_repo_url} .
    fi
  EOF
}

# Jenkins EC2 instance
resource "aws_instance" "jenkins_ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = {
    Name = "Jenkins-Server"
  }
}


