# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a complete infrastructure-as-code solution that:
- Provisions Ubuntu 24.04 VMs on LXD using Terraform (flat structure without modules)
- Configures VMs with cloud-init for automated setup
- Deploys applications via Ansible playbooks and local roles
- Manages environments (dev/prod) with separate state management per VM in Seaweed
- Provides CI/CD automation through local Gitea Actions workflows

The repository follows a flat, intentional design:
- Terraform resources are defined directly in `terraform/main.tf` without modules
- Gitea Actions workflows are defined locally in `.gitea/workflows/`
- Ansible uses local roles without external Galaxy dependencies

## Key Components

### Terraform Structure
- `terraform/main.tf`: Main resource definitions for LXD VM provisioning
- `terraform/variables.tf`: All input variables for the infrastructure
- `terraform/cloud-init/user-data.yaml`: Cloud-init template with SSH hardening and base package installation
- `terraform/env/<env>/`: Environment-specific tfvars files (dev/prod)

### Ansible Structure  
- `ansible/playbook.yml`: Main playbook that applies roles sequentially
- `ansible/roles/common/tasks/main.yml`: Installs base packages (curl, git, python, etc.)
- `ansible/roles/docker/tasks/main.yml`: Installs Docker CE from upstream repository

### Gitea Workflows
- `.gitea/workflows/terraform-check.yml`: Validates Terraform code on PRs
- `.gitea/workflows/terraform-plan.yml`: Plans Terraform changes manually
- `.gitea/workflows/terraform-apply.yml`: Applies Terraform changes manually  
- `.gitea/workflows/ansible-check.yml`: Validates Ansible playbook syntax
- `.gitea/workflows/ansible-deploy.yml`: Deploys Ansible roles to VMs

## Common Commands

### Terraform Operations
```bash
# Validate configuration
terraform validate

# Format all .tf files  
terraform fmt -check -diff

# Initialize with Seaweed backend (example for dev)
cd terraform/env/dev
terraform init \
  -backend-config="endpoint=http://seaweed-host:9000" \
  -backend-config="bucket=terraform-state" \
  -backend-config="key=state/dev/dev01/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="access_key=<key>" \
  -backend-config="secret_key=<secret>" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_metadata_api_check=true" \
  -backend-config="skip_requesting_account_id=true" \
  -backend-config="force_path_style=true"

# Plan changes
terraform plan -var-file="dev01.tfvars"

# Apply changes
terraform apply -auto-approve -var-file="dev01.tfvars"

# Show outputs
terraform output vm_ip

# Destroy VM
terraform destroy -var-file="dev01.tfvars"
```

### Ansible Operations
```bash
# Run ansible-lint on playbook
ansible-lint ansible/playbook.yml

# Validate ansible playbook syntax
ansible-playbook ansible/playbook.yml --syntax-check

# Run playbook manually (example)
VM_IP=192.168.1.100
ansible-playbook -i "$VM_IP," \
  -u ansible \
  --private-key ~/.ssh/id_rsa \
  ansible/playbook.yml
```

## Deployment Flow

1. Create/edit a `.tfvars` file under `terraform/env/<env>/`
2. Open PR → terraform-check + ansible-check run automatically
3. Merge to main
4. Manually trigger terraform-plan → review output
5. Manually trigger terraform-apply → VM is created via LXD
6. Manually trigger ansible-deploy → Ansible roles applied to live VM

## Secret Management

All secrets are configured at Gitea org level (Infra org):
- `LXD_ADDRESS`: LXD API host address
- `LXD_CLIENT_CERT`: TLS client certificate for LXD authentication
- `LXD_CLIENT_KEY`: TLS client key for LXD authentication  
- `SEAWEDD_ENDPOINT`: Seaweed S3 API URL for state backend
- `SEAWEDD_ACCESS_KEY`: Seaweed access key
- `SEAWEDD_SECRET_KEY`: Seaweed secret key
- `ANSIBLE_SSH_PUBLIC_KEY`: Injected into VM via cloud-init
- `ANSIBLE_SSH_PRIVATE_KEY`: Used by runner to SSH into VM

## VM Naming Convention

VM names follow the pattern: `<environment>-<os_type>-<vm_name>`
Examples:
- `dev-ubuntu-vm-dev01`
- `prod-ubuntu-vm-prod02`

State is stored in Seaweed at path: `s3://terraform-state/state/<environment>/<vm_name>/terraform.tfstate`