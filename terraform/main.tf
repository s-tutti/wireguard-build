# ---------------------------------------------------------------------------
# Cloud module dispatch
#
# Each cloud module exposes the same output interface:
#   - vm_public_ip
#   - ssh_command
#   - wireguard_public_key_command
#
# To add a new cloud provider, create modules/<provider>/ with the same
# variable / output interface, and add a module block + count condition here.
# ---------------------------------------------------------------------------

module "azure" {
  count  = var.cloud == "azure" ? 1 : 0
  source = "./modules/azure"

  project_name             = var.project_name
  environment              = var.environment
  location                 = var.azure_location
  vm_size                  = var.azure_vm_size
  admin_username           = var.admin_username
  ssh_public_key           = var.ssh_public_key
  allowed_ssh_cidr         = var.allowed_ssh_cidr
  wireguard_port           = var.wireguard_port
  wireguard_server_address = var.wireguard_server_address
}
