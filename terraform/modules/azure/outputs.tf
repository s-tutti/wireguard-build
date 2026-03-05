output "vm_public_ip" {
  description = "Public IP address of the VM."
  value       = azurerm_public_ip.main.ip_address
}

output "ssh_command" {
  description = "SSH command to connect to the VM."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "wireguard_public_key_command" {
  description = "SSH command that prints the WireGuard server public key (run after cloud-init finishes)."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address} 'sudo cat /etc/wireguard/server_public.key'"
}
