# ---------------------------------------------------------------------------
# Cloud selection
# ---------------------------------------------------------------------------
variable "cloud" {
  description = "Cloud provider to deploy to. Currently supported: \"azure\"."
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure"], var.cloud)
    error_message = "Supported values: \"azure\"."
  }
}

# ---------------------------------------------------------------------------
# Common — used by every cloud module
# ---------------------------------------------------------------------------
variable "project_name" {
  description = "Short project identifier used as a prefix for all resource names."
  type        = string
  default     = "wireguard"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod). Used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "admin_username" {
  description = "OS-level admin username for the VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key content (e.g. contents of ~/.ssh/id_rsa.pub). Required."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR that is allowed to reach the VM on port 22. Restrict to your own IP for security (e.g. \"203.0.113.10/32\")."
  type        = string
  default     = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# WireGuard
# ---------------------------------------------------------------------------
variable "wireguard_port" {
  description = "UDP port WireGuard listens on."
  type        = number
  default     = 51820
}

variable "wireguard_server_address" {
  description = "IP address (with CIDR prefix) assigned to the WireGuard interface on the server (e.g. \"10.100.0.1/24\")."
  type        = string
  default     = "10.100.0.1/24"
}

# ---------------------------------------------------------------------------
# Azure-specific
# ---------------------------------------------------------------------------
variable "azure_location" {
  description = "Azure region to deploy resources in (e.g. \"eastus\", \"japaneast\", \"westeurope\")."
  type        = string
  default     = "japaneast"
}

variable "azure_vm_size" {
  description = "Azure VM SKU. Defaults to Standard_B1s (1 vCPU / 1 GB RAM — cheapest general-purpose option)."
  type        = string
  default     = "Standard_B1s"
}
