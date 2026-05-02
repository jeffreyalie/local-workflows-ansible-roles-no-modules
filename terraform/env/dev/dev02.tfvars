# ---------------------------------------------------------------
# Rename this file to terraform.tfvars and fill in your values.
# DO NOT commit terraform.tfvars with real keys to the repository.
# Use Gitea Secrets (TF_VAR_ansible_ssh_public_key) instead.
# ---------------------------------------------------------------

# vm_name = "dev-ubuntu-vm-dev02"    # Passed from GHA input TFVAR_vm_name (e.g. dev-ubuntu-vm-dev01 / prod-ubuntu-vm-prod01)

# Paste your ansible user's SSH public key here
# ansible_ssh_public_key = "ssh-ed25519 AAAA... user@host"

image        = "ubuntu-24-04-vm"
os_type      = "ubuntu-vm"
network      = "lxdbr0"
storage_pool = "default"
disk_size    = "10GiB"
cpu_count    = 2
memory_size  = "2GiB"