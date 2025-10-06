# AWS Region and Instance Settings
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# Optional override AMI. Leave empty to auto-detect Amazon Linux 2023
variable "ami_id" {
  description = "Override AMI ID (leave empty to auto-select AL2023)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# SSH Access Control
variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access (restrict this to your IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -------------------------------
# GITHUB REPOSITORY CONFIGURATION
# -------------------------------

# 🔧 EDIT THIS: paste your GitHub repo HTTPS or SSH URL
# Example: "https://github.com/digitalwitchdemo/mediplus.git"
variable "github_repo_url" {
  description = "Optional GitHub repository to clone on the EC2 instance"
  type        = string
  default     = "https://github.com/YOUR_USERNAME/YOUR_REPO.git"
}

# 🔧 EDIT THIS: branch name to clone (e.g. main, master, develop)
variable "github_repo_branch" {
  description = "Branch to clone from the repo"
  type        = string
  default     = "main"
}

# 🔧 EDIT THIS: where on the EC2 instance the repo should live
# Example: "/home/ec2-user/mediplus"
variable "repo_clone_path" {
  description = "Path on EC2 to clone the repo into"
  type        = string
  default     = "/home/ec2-user/app"
}

# Optional — whether to install text editors like vim/nano
variable "install_editors" {
  description = "Install vim/nano editors (true/false)"
  type        = bool
  default     = false
}