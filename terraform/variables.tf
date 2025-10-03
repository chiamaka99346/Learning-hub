variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Amazon Linux 2 recommended)"
  type        = string
  default     = "ami-052064a798f08f0d3"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the existing AWS key pair"
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "jenkins_http_port" {
  description = "Jenkins web UI port"
  type        = number
  default     = 8080
}

variable "jenkins_agent_port" {
  description = "Jenkins inbound agent (JNLP) port"
  type        = number
  default     = 50000
}

variable "extra_tags" {
  description = "Additional tags to add to resources"
  type        = map(string)
  default     = {}
}

variable "github_repo_url" {
  description = "Git repository URL to clone on the EC2 instance (leave empty to skip)"
  type        = string
  default     = "https://github.com/your-username/your-repo.git"
}

variable "github_repo_branch" {
  description = "Git branch to checkout"
  type        = string
  default     = "main"
}

variable "repo_clone_path" {
  description = "Directory on the instance to clone the repository into"
  type        = string
  default     = "/home/ec2-user/app"
}

variable "git_use_ssh" {
  description = "If true, prepare SSH for Git cloning (use SSH repo URL)"
  type        = bool
  default     = false
}

variable "git_ssh_private_key" {
  description = "PEM-encoded SSH private key for Git (leave empty to skip)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "git_config_user_name" {
  description = "Git user.name to set globally on the instance"
  type        = string
  default     = "ec2-user"
}

variable "git_config_user_email" {
  description = "Git user.email to set globally on the instance"
  type        = string
  default     = "ec2-user@local"
}

variable "install_editors" {
  description = "Install common editors (vim, nano) for on-box edits"
  type        = bool
  default     = true
}


