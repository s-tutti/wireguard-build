locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_subnet" "main" {
  name                 = "snet-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ---------------------------------------------------------------------------
# Network Security Group
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "main" {
  name                = "nsg-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowWireGuard"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.wireguard_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ---------------------------------------------------------------------------
# Public IP + NIC
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "main" {
  name                = "pip-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "main" {
  name                 = "nic-${local.name_prefix}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  # Required for the VM to forward packets between the WireGuard tunnel and
  # the internet (acts as a NAT gateway for VPN clients).
  ip_forwarding_enabled = true
  tags                 = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ---------------------------------------------------------------------------
# Virtual Machine
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.main.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Ubuntu 22.04 LTS (Jammy) — has first-class WireGuard kernel module support
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Cloud-init installs and configures WireGuard on first boot.
  # Template variables: wg_server_address, wg_port
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    wg_server_address = var.wireguard_server_address
    wg_port           = var.wireguard_port
  }))
}
