locals {
  active_module = var.cloud == "azure" ? module.azure[0] : null
}

output "vm_public_ip" {
  description = "Public IP address of the WireGuard server."
  value       = local.active_module.vm_public_ip
}

output "wireguard_endpoint" {
  description = "WireGuard endpoint in host:port format."
  value       = "${local.active_module.vm_public_ip}:${var.wireguard_port}"
}

output "ssh_command" {
  description = "SSH command to connect to the server."
  value       = local.active_module.ssh_command
}

output "wireguard_public_key_command" {
  description = "Command to retrieve the WireGuard server public key after setup completes."
  value       = local.active_module.wireguard_public_key_command
}
