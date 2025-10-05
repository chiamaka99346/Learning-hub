variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  type        = string
  default     = "ami-052064a798f08f0d3"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "client 2 key"
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "github_repo_url" {
  description = "Optional GitHub repository to clone"
  type        = string
  default     = ""
}

variable "github_repo_branch" {
  description = "Branch to clone from the repo"
  type        = string
  default     = "main"
}

variable "repo_clone_path" {
  description = "Path on EC2 to clone repo into"
  type        = string
  default     = "/home/ec2-user/app"
}

variable "install_editors" {
  description = "Install vim/nano editors"
  type        = bool
  default     = true
}


