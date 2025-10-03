## Deployment Guide

### Prerequisites
- AWS account with permissions for EC2, VPC, and IAM
- Terraform >= 1.5 installed locally or run from Jenkins
- Jenkins with the following credentials configured:
  - `aws-credentials`: AWS Access Key + Secret (sufficient permissions)
  - `deployment-server-ssh`: SSH private key matching the EC2 `key_name`
  - `docker-registry-credentials`: Docker Hub credentials (optional if pushing)

### Terraform (EC2 + Security Group + Jenkins)
Files: `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`

Open ports created by the security group:
- 22: SSH (restricted via `ssh_cidr_blocks` variable)
- 8080: Jenkins UI (`jenkins_http_port`)
- 50000: Jenkins inbound agents (`jenkins_agent_port`)

Key variables (can be set via CLI, Jenkins, or defaults):
- `aws_region` (default `us-east-1`)
- `ami_id` (Amazon Linux 2 AMI recommended)
- `instance_type` (e.g., `t3.micro`)
- `key_name` (existing AWS key pair)
- `ssh_cidr_blocks` (e.g., `["x.x.x.x/32"]` for your IP)
- `github_repo_url` (repo to clone on the instance)
- `github_repo_branch` (default `main`)
- `repo_clone_path` (default `/home/ec2-user/app`)
- `git_use_ssh`, `git_ssh_private_key`, `git_config_user_name`, `git_config_user_email`

Inline overrides (fast edit in `terraform/main.tf`):
- Edit the block labeled "Optional: Inline overrides (EDIT HERE)" to set:
  - `local.github_repo_url_override`
  - `local.github_repo_branch_override`
  - `local.repo_clone_path_override`

Local Terraform commands:
```bash
cd terraform
terraform init
terraform apply -auto-approve \
  -var aws_region="us-east-1" \
  -var ami_id="ami-xxxxxxxx" \
  -var instance_type="t3.micro" \
  -var key_name="your-keypair" \
  -var 'ssh_cidr_blocks=["x.x.x.x/32"]' \
  -var github_repo_url="https://github.com/your/repo.git"

terraform output
```

Outputs:
- `public_ip`: EC2 public IP
- `jenkins_url`: `http://<public_dns>:<jenkins_http_port>`

### Jenkins Pipeline
File: `Jenkinsfile`

Important parameters:
- `APPLY_TERRAFORM`: true to provision EC2 from Jenkins
- `USE_TERRAFORM_OUTPUT`: true to auto-resolve EC2 host from `terraform/public_ip`
- `AWS_REGION`, `AMI_ID`, `INSTANCE_TYPE`, `KEY_NAME`, `SSH_CIDR`
- `JENKINS_HTTP_PORT`, `JENKINS_AGENT_PORT`
- `GITHUB_REPO_URL`, `GITHUB_REPO_BRANCH`, `REPO_CLONE_PATH`
- `GIT_USE_SSH`, `GIT_SSH_PRIVATE_KEY`, `GIT_USER_NAME`, `GIT_USER_EMAIL`

Typical run (from Jenkins UI):
1. Set `APPLY_TERRAFORM=true` (first run) and provide `AMI_ID`, `KEY_NAME`, and `SSH_CIDR`.
2. Leave `USE_TERRAFORM_OUTPUT=true` to use the new EC2 IP automatically.
3. Set `DEPLOY_ENV=prod` to deploy the Dockerized app to EC2.

### Accessing Jenkins
- Jenkins UI: `http://<EC2 Public IP>:8080` (or your configured port)
- Initial admin password on the instance: `/var/lib/jenkins/secrets/initialAdminPassword`

### Updating and Redeploying
- Edit files locally and push to GitHub.
- Re-run the Jenkins pipeline with a new `IMAGE_TAG` or let it use the build number.

### Notes
- For better security, restrict `ssh_cidr_blocks` to your public IP.
- If using SSH for Git cloning, set a read-only deploy key on GitHub and provide it via `GIT_SSH_PRIVATE_KEY` (or Terraform var `git_ssh_private_key`).

