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
  region = us-east-1
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

###############################################
# Optional: https://github.com/chiamaka99346/Learning-hub.git (EDIT HERE)
# Set these to non-empty strings to override variables without
# touching variables.tf or pipeline params.
###############################################
locals {
  github_repo_url_override    = ""     # e.g., "https://github.com/your-username/your-repo.git"
  github_repo_branch_override = ""     # e.g., "main"
  repo_clone_path_override    = ""     # e.g., "/home/ec2-user/app"

  repo_url    = length(trimspace(local.github_repo_url_override)) > 0 ? local.github_repo_url_override : var.github_repo_url
  repo_branch = length(trimspace(local.github_repo_branch_override)) > 0 ? local.github_repo_branch_override : var.github_repo_branch
  repo_path   = length(trimspace(local.repo_clone_path_override)) > 0 ? local.repo_clone_path_override : var.repo_clone_path
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins ports"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description = "Jenkins HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins Agent (JNLP)"
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

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    yum update -y
    amazon-linux-extras install -y java-openjdk17

    rpm --import https://pkg.jenkins.io/redhat/jenkins.io-2023.key
    cat >/etc/yum.repos.d/jenkins.repo <<'REPO'
    [jenkins]
    name=Jenkins-stable
    baseurl=https://pkg.jenkins.io/redhat-stable
    gpgcheck=1
    gpgkey=https://pkg.jenkins.io/redhat/jenkins.io-2023.key
    REPO

    yum install -y jenkins git
    if [ ${var.install_editors} = true ]; then
      yum install -y vim-enhanced nano || true
    fi

    systemctl enable jenkins
    systemctl start jenkins

    # Adjust Jenkins HTTP port if different from default
    if ! grep -q "JENKINS_PORT=${var.jenkins_http_port}" /etc/sysconfig/jenkins; then
      sed -i "s/^JENKINS_PORT=.*/JENKINS_PORT=${var.jenkins_http_port}/" /etc/sysconfig/jenkins || true
      systemctl restart jenkins || true
    fi

    # Optionally clone repository if provided
    if [ -n "${local.repo_url}" ]; then
      # Prepare SSH for git if requested
      if [ ${var.git_use_ssh} = true ] && [ -n "${var.git_ssh_private_key}" ]; then
        install -d -m 700 -o ec2-user -g ec2-user /home/ec2-user/.ssh
        echo "${var.git_ssh_private_key}" > /home/ec2-user/.ssh/id_rsa
        chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
        chmod 600 /home/ec2-user/.ssh/id_rsa
        ssh-keyscan -t rsa github.com >> /home/ec2-user/.ssh/known_hosts 2>/dev/null || true
        chown ec2-user:ec2-user /home/ec2-user/.ssh/known_hosts || true
        chmod 644 /home/ec2-user/.ssh/known_hosts || true
      fi

      # Configure git identity
      sudo -u ec2-user git config --global user.name "${var.git_config_user_name}" || true
      sudo -u ec2-user git config --global user.email "${var.git_config_user_email}" || true

      mkdir -p ${local.repo_path}
      chown -R ec2-user:ec2-user ${local.repo_path} || true
      if [ -d "${local.repo_path}/.git" ]; then
        sudo -u ec2-user git -C ${local.repo_path} fetch --all || true
        sudo -u ec2-user git -C ${local.repo_path} checkout ${local.repo_branch} || true
        sudo -u ec2-user git -C ${local.repo_path} pull origin ${local.repo_branch} || true
      else
        sudo -u ec2-user git clone --branch ${local.repo_branch} ${local.repo_url} ${local.repo_path}
      fi
    fi
  EOF
}

resource "aws_instance" "jenkins_ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = local.user_data

  tags = merge({
    Name = "Jenkins-EC2"
  }, var.extra_tags)
}

