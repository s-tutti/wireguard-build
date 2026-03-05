variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "admin_username" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "wireguard_port" {
  type    = number
  default = 51820
}

variable "wireguard_server_address" {
  type    = string
  default = "10.100.0.1/24"
}
