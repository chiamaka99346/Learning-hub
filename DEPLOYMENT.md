# Jenkins EC2 Infrastructure Deployment Guide

## 🚀 Quick Start

Your infrastructure is **DEPLOYED** and ready to use:

- **Jenkins URL:** `http://54.158.58.154:8080`
- **Public IP:** `54.158.58.154`
- **Instance ID:** `i-066c26c2b67256c40`
- **SSH Key:** `client 2 key`

## 📋 Prerequisites

### Required Software
- AWS CLI configured with credentials
- Terraform >= 1.5.0
- Git (for repository management)
- SSH client (for EC2 access)

### AWS Permissions Required
- EC2: Create instances, security groups, key pairs
- VPC: Read default VPC and subnets
- IAM: Basic permissions for EC2 operations

### Jenkins Credentials Setup
Configure these credentials in Jenkins:
- `aws-credentials`: AWS Access Key + Secret
- `deployment-server-ssh`: SSH private key matching `client 2 key`
- `docker-registry-credentials`: Docker Hub credentials (optional)

## 🏗️ Infrastructure Overview

### Created Resources
1. **EC2 Instance (Jenkins-EC2)**
   - AMI: `ami-052064a798f08f0d3` (Amazon Linux 2)
   - Instance Type: `t3.micro`
   - Key Pair: `client 2 key`
   - Public IP: `54.158.58.154`

2. **Security Group (jenkins-sg)**
   - SSH (22): Open to all (configure for your IP)
   - Jenkins UI (8080): Open to all
   - Jenkins Agents (80): Open to all

3. **User Data Script**
   - Installs Java 17
   - Installs Jenkins from official repository
   - Configures Jenkins service
   - Optionally clones Git repositories

## 🔧 Terraform Configuration

### File Structure
```
terraform/
├── main.tf          # Main infrastructure configuration
├── variables.tf     # Variable definitions
└── outputs.tf       # Output values
```

### Key Variables
```hcl
# Core Infrastructure
aws_region = "us-east-1"
ami_id = "ami-052064a798f08f0d3"
instance_type = "t3.micro"
key_name = "client 2 key"

# Security
ssh_cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP

# Jenkins Configuration
jenkins_http_port = 8080
jenkins_agent_port = 50000

# Git Repository (Optional)
github_repo_url = "https://github.com/chiamaka99346/Learning-hub.git"
github_repo_branch = "main"
repo_clone_path = "/home/ec2-user/app"
```

### Inline Overrides (Fast Edit)
Edit `terraform/main.tf` lines 32-34:
```hcl
locals {
  github_repo_url_override    = "https://github.com/your-username/your-repo.git"
  github_repo_branch_override = "main"
  repo_clone_path_override    = "/home/ec2-user/app"
}
```

## 🚀 Deployment Commands

### Initial Deployment
```bash
cd terraform
terraform init
terraform apply -auto-approve \
  -var aws_region="us-east-1" \
  -var ami_id="ami-052064a798f08f0d3" \
  -var key_name="client 2 key"
```

### Update Infrastructure
```bash
terraform plan
terraform apply
```

### Destroy Infrastructure
```bash
terraform destroy
```

## 🔐 Accessing Jenkins

### 1. Get Initial Admin Password
```bash
# SSH to the instance
ssh -i "path/to/client-2-key.pem" ec2-user@54.158.58.154

# Get Jenkins initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 2. Access Jenkins Web UI
- URL: `http://54.158.58.154:8080`
- Enter the initial password from step 1
- Follow the setup wizard

### 3. Configure Jenkins
- Install suggested plugins
- Create admin user
- Configure instance settings

## 🔄 Jenkins Pipeline Usage

### Pipeline Parameters
The `Jenkinsfile` supports these parameters:

#### Infrastructure Parameters
- `APPLY_TERRAFORM`: Deploy/update EC2 infrastructure
- `USE_TERRAFORM_OUTPUT`: Auto-resolve EC2 host from Terraform
- `AWS_REGION`: AWS region (default: us-east-1)
- `AMI_ID`: AMI ID for EC2
- `INSTANCE_TYPE`: EC2 instance type
- `KEY_NAME`: AWS key pair name
- `SSH_CIDR`: CIDR allowed for SSH access

#### Git Repository Parameters
- `GITHUB_REPO_URL`: Repository to clone
- `GITHUB_REPO_BRANCH`: Branch to checkout
- `REPO_CLONE_PATH`: Path to clone repository
- `GIT_USE_SSH`: Use SSH for Git operations
- `GIT_SSH_PRIVATE_KEY`: SSH private key for Git
- `GIT_USER_NAME`: Git user name
- `GIT_USER_EMAIL`: Git user email

#### Deployment Parameters
- `EC2_HOST`: EC2 public DNS or IP
- `EC2_USER`: SSH user (ec2-user for Amazon Linux)
- `APP_PORT`: Application port (default: 8080)
- `IMAGE_TAG`: Docker image tag
- `DEPLOY_ENV`: Deployment environment (prod/staging/none)

### Running the Pipeline

#### First Time Setup
1. Set `APPLY_TERRAFORM=true`
2. Provide `AMI_ID`, `KEY_NAME`, `SSH_CIDR`
3. Set `DEPLOY_ENV=prod`
4. Run the pipeline

#### Subsequent Deployments
1. Set `USE_TERRAFORM_OUTPUT=true`
2. Set `DEPLOY_ENV=prod`
3. Optionally set `IMAGE_TAG`
4. Run the pipeline

## 🔒 Security Best Practices

### Restrict SSH Access
Update `terraform/variables.tf`:
```hcl
variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["YOUR_IP/32"]  # Replace with your IP
}
```

### Use IAM Roles
For production, consider using IAM roles instead of access keys:
```hcl
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-ec2-profile"
  role = aws_iam_role.jenkins_role.name
}
```

## 📊 Monitoring and Logs

### Check Jenkins Status
```bash
ssh -i "path/to/client-2-key.pem" ec2-user@54.158.58.154
sudo systemctl status jenkins
sudo journalctl -u jenkins -f
```

### View Jenkins Logs
```bash
sudo tail -f /var/log/jenkins/jenkins.log
```

### Check Application Logs
```bash
# If using Docker
docker logs edukate-learning-platform

# Check system resources
htop
df -h
```

## 🔧 Troubleshooting

### Common Issues

#### Jenkins Won't Start
```bash
sudo systemctl restart jenkins
sudo systemctl status jenkins
```

#### Can't Access Jenkins UI
1. Check security group allows port 8080
2. Verify Jenkins is running: `sudo systemctl status jenkins`
3. Check firewall: `sudo iptables -L`

#### SSH Connection Issues
1. Verify key pair name matches exactly
2. Check security group allows port 22
3. Ensure private key file has correct permissions: `chmod 400 key.pem`

#### Terraform Apply Fails
1. Check AWS credentials: `aws sts get-caller-identity`
2. Verify key pair exists: `aws ec2 describe-key-pairs`
3. Check AMI availability in your region

### Useful Commands

#### Check Infrastructure Status
```bash
terraform show
terraform output
```

#### View Terraform State
```bash
terraform state list
terraform state show aws_instance.jenkins_ec2
```

#### Update Infrastructure
```bash
terraform plan -var="instance_type=t3.small"
terraform apply
```

## 📝 Maintenance

### Regular Updates
- Update Jenkins plugins regularly
- Monitor EC2 instance health
- Review security group rules
- Update AMI to latest version

### Backup Strategy
- Backup Jenkins configuration
- Export Jenkins jobs and pipelines
- Consider EBS snapshots for data persistence

### Cost Optimization
- Use appropriate instance types
- Implement auto-shutdown schedules
- Monitor CloudWatch costs

## 🆘 Support

### Getting Help
1. Check Jenkins logs: `/var/log/jenkins/jenkins.log`
2. Review Terraform state: `terraform show`
3. Check AWS CloudWatch logs
4. Verify security group configurations

### Useful Resources
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)

---

**Current Infrastructure Status:**
- ✅ EC2 Instance: `i-066c26c2b67256c40`
- ✅ Security Group: `sg-0428acdf697fcd3a3`
- ✅ Jenkins URL: `http://54.158.58.154:8080`
- ✅ Public IP: `54.158.58.154`

**Next Steps:**
1. Access Jenkins at the URL above
2. Complete Jenkins setup wizard
3. Configure your first pipeline
4. Deploy your applications