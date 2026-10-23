# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This repository implements a complete infrastructure-as-code solution that:
- Provisions Ubuntu 24.04 VMs on LXD using Terraform with a flat, no-module approach
- Configures VMs with cloud-init for automated setup
- Deploys applications via Ansible playbooks and local roles
- Manages environments (dev/prod) with separate state management per VM in MinIO
- Provides CI/CD automation through local Gitea Actions workflows

## Repository Structure

```
.
├── .gitea/
│   └── workflows/                  # Gitea Actions workflows for CI/CD
├── terraform/
│   ├── env/                        # Environment-specific configurations
│   │   ├── dev/                    # Development environment
│   │   └── prod/                   # Production environment  
│   ├── cloud-init/                 # Cloud-init templates
│   ├── main.tf                     # LXD provider + VM resource (flat, no modules)
│   ├── variables.tf                # All input variables
│   └── outputs.tf                  # VM name, IP, MAC, SSH command
├── ansible/
│   ├── playbook.yml                # Main Ansible playbook
│   ├── inventory.yml               # Dynamic inventory
│   └── roles/                      # Local Ansible roles
└── README.md                       # Project documentation
```

## Key Components

### Terraform
- Uses a flat approach with resources defined directly in `terraform/main.tf` (no modules)
- Each environment (`dev`, `prod`) has its own root module that calls the shared configuration
- State is managed in MinIO with separate files per VM: `s3://terraform-state/state/<environment>/<vm_name>/terraform.tfstate`
- VM naming convention: `<environment>-<os_type>-<vm_name>` (e.g. `dev-ubuntu-vm-dev01`)
- Cloud-init configuration is rendered by Terraform and injected into LXD instances

### Ansible
- Uses local roles (`ansible/roles/`) without external dependencies
- Playbook applies two roles in sequence: `common` (base packages) and `docker` (Docker CE installation)
- Inventory is dynamic, set via the `VM_IP` environment variable
- SSH hardening is implemented in cloud-init template with password authentication disabled

### Gitea Workflows
- All workflows are defined locally in `.gitea/workflows/`
- Includes Terraform check, plan, apply, and destroy workflows
- Ansible check and deploy workflows for static analysis and deployment
- Secrets are managed at the Gitea org level (`Infra` org)

## Common Commands

### Terraform
```bash
# Validate configuration
terraform validate

# Format all .tf files  
terraform fmt -check -diff

# Initialize environment with MinIO backend
cd terraform/env/dev
terraform init -backend-config="endpoint=http://minio-host:9000" \
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

### Ansible
```bash
# Run ansible-lint on playbook
ansible-lint ansible/playbook.yml

# Validate playbook syntax
ansible-playbook ansible/playbook.yml --syntax-check

# Run playbook manually (example)
VM_IP=192.168.1.100
ansible-playbook -i "$VM_IP," \
  -u ansible \
  --private-key ~/.ssh/id_rsa \
  ansible/playbook.yml
```

## Development Workflow

1. Create a new `.tfvars` file under `terraform/env/<env>/` for each new VM
2. Run Terraform Check and Plan via Gitea Actions
3. Run Ansible Check via Gitea Actions 
4. Open a PR and merge to `main`
5. Run Terraform Apply via Gitea Actions to create the VM
6. Run Ansible Deploy via Gitea Actions to configure the VM

## Secrets Management

All secrets are configured at the Gitea org level:
- `LXD_ADDRESS`, `LXD_CLIENT_CERT`, `LXD_CLIENT_KEY` for LXD connection
- `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` for Terraform state backend
- `ANSIBLE_SSH_PUBLIC_KEY`, `ANSIBLE_SSH_PRIVATE_KEY` for Ansible deployment

## Security Notes

- SSH hardening enabled in cloud-init template
- Password authentication disabled for ansible user
- SSH keys used for both Terraform LXD connections and Ansible deployment
- All secrets are managed through Gitea org level variables, not stored in code

## Implementation Details

### Terraform Resources
The repository uses a flat Terraform structure with resources defined directly in `main.tf`. Key components:
- LXD provider configured to use TLS certificates from workflow secrets
- VM resource using cloud-init template for automated setup
- Cloud-init template configures the ansible user with SSH key authentication and hardens SSH settings

### Ansible Roles
The Ansible playbook uses two local roles:
1. `common` - Installs base packages (curl, unzip, git, ca-certificates)
2. `docker` - Installs Docker CE from upstream repository with proper GPG key handling

### Cloud-init Template
The cloud-init configuration (`terraform/cloud-init/user-data.yaml`) handles:
- Setting hostname to the full instance name
- Configuring DHCP on network interface
- Creating ansible user with SSH key auth and passwordless sudo
- Installing base packages (curl, wget, git, python3, openssh-server)
- Hardening SSH settings (disables password auth and root login)

## Local Development Usage

```bash
# 1. Copy a tfvars example and fill in secrets locally
cp terraform/env/dev/dev01.tfvars terraform/terraform.tfvars
# Add lxd_address and ansible_ssh_public_key

# 2. Init with MinIO backend
cd terraform
terraform init \
  -backend-config="endpoint=http://10.248.42.22:9000" \
  -backend-config="bucket=terraform-state" \
  -backend-config="key=state/dev/dev01/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="access_key=<key>" \
  -backend-config="secret_key=<secret>" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_metadata_api_check=true" \
  -backend-config="skip_requesting_account_id=true" \
  -backend-config="force_path_style=true"

# 3. Plan and apply
terraform plan -var-file="env/dev/dev01.tfvars"
terraform apply -var-file="env/dev/dev01.tfvars"

# 4. Get SSH command
terraform output ansible_ssh_command

# 5. Run Ansible manually
VM_IP=$(terraform output -raw vm_ip)
ansible-playbook -i "$VM_IP," \
  -u ansible \
  --private-key ~/.ssh/id_ed25519 \
  ../ansible/playbook.yml
```