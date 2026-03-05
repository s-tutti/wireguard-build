# WireGuard on Cloud — Terraform

Terraform project that provisions a WireGuard VPN server on a cloud VM.
Azure is the first supported provider; the module structure makes adding
AWS, GCP, or others straightforward.

## ✨ Features

- **One-command deployment**: `terraform apply` creates a complete VPN server
- **Automated client setup**: Scripts handle key generation and configuration
- **Multi-platform**: Windows, Mac, Linux, iOS, Android
- **QR code support**: Scan and connect from smartphones in seconds
- **Secure by default**: Modern cryptography with minimal configuration

## 🚀 Quick Navigation

- New user? Start with [Quick Start](#quick-start) (5 minutes to deploy)
- Need to add a device? See [WireGuard Client Setup](#wireguard-client-setup)
- Smartphone? Jump to [Smartphone Setup](#-smartphone-ios--android)

---

## Project Structure

```
.
├── .gitignore
├── README.md
├── scripts/
│   ├── setup-client.sh          # Automated client setup (Linux/Mac)
│   ├── setup-client.ps1         # Automated client setup (Windows PowerShell)
│   ├── add-client.sh            # Server-side client addition
│   ├── show-qr.sh               # Generate QR codes (Linux/Mac)
│   └── show-qr.ps1              # Generate QR codes (Windows PowerShell)
└── terraform/
    ├── providers.tf             # Provider requirements & backend (local state)
    ├── main.tf                  # Cloud module dispatch
    ├── variables.tf             # All input variables (root)
    ├── outputs.tf               # Unified outputs
    ├── terraform.tfvars.example # Copy → terraform.tfvars and fill in values
    └── modules/
        └── azure/               # Azure implementation
            ├── main.tf          # RG, VNet, NSG, Public IP, NIC, VM
            ├── variables.tf
            ├── outputs.tf
            └── templates/
                └── cloud-init.yaml.tpl   # First-boot WireGuard installation
```

---

## Prerequisites

The following tools must be installed and configured before running Terraform:

| Tool | Purpose |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5 | Infrastructure provisioning |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | Azure authentication |

Log in to Azure before applying:

```bash
az login
# Optional: select a specific subscription
az account set --subscription "<subscription-id>"
```

---

## Setting Up `ssh_public_key`

`ssh_public_key` is the **only required variable** with no default.
It is the public half of an SSH key pair — the private key stays on your machine
and is never uploaded anywhere.

### Step 1 — Check for an existing key

```bash
ls ~/.ssh/*.pub
```

If files like `id_rsa.pub`, `id_ed25519.pub`, or `id_ecdsa.pub` are listed,
you already have a key pair and can skip to Step 3.

### Step 2 — Generate a new key pair (if needed)

> **Azure requires RSA keys.** Ed25519 and ECDSA keys are not accepted by
> Azure Linux VMs. Use RSA 4096:

```bash
ssh-keygen -t rsa -b 4096 -C "wireguard-terraform"
# Accept the default path (~/.ssh/id_rsa) or specify another.
# Setting a passphrase is strongly recommended.
```

### Step 3 — Copy the public key content

```bash
cat ~/.ssh/id_rsa.pub
# Example output:
# ssh-rsa AAAAB3NzaC1yc2EAAAA... wireguard-terraform
```

### Step 4 — Set it in `terraform.tfvars`

Paste the **entire output** of the `cat` command as the value.
The value must be on a single line and include the key type prefix:

```hcl
# terraform/terraform.tfvars
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAA... wireguard-terraform"
```

> **Note:** Do not paste the private key (`id_rsa`, without `.pub`).
> It must never leave your machine.

### Alternative — pass the key inline without editing the file

```bash
terraform apply -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

---

## Quick Start

### 1. Configure SSH Key

Generate an SSH key if you don't have one:

```bash
ssh-keygen -t rsa -b 4096 -C "wireguard-terraform"
```

### 2. Deploy the Server

```bash
cd terraform/

# Create config file
cp terraform.tfvars.example terraform.tfvars

# Edit and set your SSH public key (required)
nano terraform.tfvars
# Set: ssh_public_key = "ssh-rsa AAAAB3NzaC1yc..."
# (Get it with: cat ~/.ssh/id_rsa.pub)

# Deploy
terraform init
terraform apply
```

Terraform will output the server IP address:

```
vm_public_ip = "20.123.45.67"
```

### 3. Wait for Setup (~2 minutes)

Cloud-init installs WireGuard in the background. Check if ready:

```bash
ssh azureuser@<vm_public_ip> 'sudo cat /etc/wireguard/server_public.key'
```

If the file exists, setup is complete!

### 4. Add Your First Client

```bash
# Automated setup (from project root):
./scripts/setup-client.sh <vm_public_ip>

# Then import the config file into your WireGuard app
# See "WireGuard Client Setup" section below for details
```

That's it! Your VPN is ready to use.

---

## Configuration Reference

All variables live in `terraform/variables.tf`. Override them in `terraform.tfvars`.

### Common

| Variable | Default | Description |
|---|---|---|
| `cloud` | `"azure"` | Cloud provider (`"azure"`) |
| `project_name` | `"wireguard"` | Prefix for resource names |
| `environment` | `"dev"` | Environment tag (`dev`, `staging`, `prod`) |
| `admin_username` | `"azureuser"` | OS admin username |
| `ssh_public_key` | *(required)* | Contents of your SSH public key file |
| `allowed_ssh_cidr` | `"0.0.0.0/0"` | CIDR allowed to SSH in — restrict to your IP |

### WireGuard

| Variable | Default | Description |
|---|---|---|
| `wireguard_port` | `51820` | UDP listen port |
| `wireguard_server_address` | `"10.100.0.1/24"` | Server tunnel interface address |

### Azure

| Variable | Default | Description |
|---|---|---|
| `azure_location` | `"japaneast"` | Azure region |
| `azure_vm_size` | `"Standard_B1s"` | VM SKU (1 vCPU / 1 GB RAM, ~$7.59/mo) |

---

## WireGuard Client Setup

### 🚀 Automated Setup (Recommended)

The easiest way to add a new client:

#### Linux / Mac

```bash
# From your local machine:
./scripts/setup-client.sh <vm_public_ip>

# Example:
./scripts/setup-client.sh 20.123.45.67

# With custom name and IP:
./scripts/setup-client.sh 20.123.45.67 my-laptop 10.100.0.3
```

#### Windows (PowerShell)

```powershell
# From PowerShell:
.\scripts\setup-client.ps1 -ServerIP <vm_public_ip>

# Example:
.\scripts\setup-client.ps1 -ServerIP 20.123.45.67

# With custom name and IP:
.\scripts\setup-client.ps1 -ServerIP 20.123.45.67 -ClientName my-laptop -ClientIP 10.100.0.3
```

> **Note for Windows users**: OpenSSH Client must be installed.
> Go to: Settings → Apps → Optional features → OpenSSH Client

This script will:
1. Generate client keys on the server
2. Register the client automatically
3. Download the config file to `~/wireguard-configs/` (or `%USERPROFILE%\wireguard-configs\` on Windows)

Then follow the instructions below for your device type.

---

### 📱 Smartphone (iOS / Android)

#### Method 1: QR Code (Easiest)

1. **Install WireGuard app**
   - iOS: [App Store](https://apps.apple.com/us/app/wireguard/id1441195209)
   - Android: [Google Play](https://play.google.com/store/apps/details?id=com.wireguard.android)

2. **Generate QR code**

   **Linux / Mac:**
   ```bash
   ./scripts/show-qr.sh <vm_public_ip> <client-name>

   # Example:
   ./scripts/show-qr.sh 20.123.45.67 my-iphone
   ```

   **Windows (PowerShell):**
   ```powershell
   .\scripts\show-qr.ps1 -ServerIP <vm_public_ip> -ClientName <client-name>

   # Example:
   .\scripts\show-qr.ps1 -ServerIP 20.123.45.67 -ClientName my-iphone
   ```

3. **Scan with WireGuard app**
   - Open the app and tap **+** (plus icon)
   - Select **Create from QR code**
   - Scan the displayed QR code

4. **Activate the tunnel**
   - Toggle the switch to connect

#### Method 2: Import Config File

1. Transfer `~/wireguard-configs/<client-name>.conf` to your phone
   (via email, cloud storage, AirDrop, etc.)

2. In the WireGuard app:
   - Tap **+** → **Create from file or archive**
   - Select the `.conf` file

---

### 💻 Desktop (Windows / Mac / Linux)

1. **Install WireGuard**
   - Download from [https://www.wireguard.com/install/](https://www.wireguard.com/install/)

2. **Import configuration**
   - Open the WireGuard app
   - Click **Add Tunnel** → **Import from file**
   - Select `~/wireguard-configs/<client-name>.conf`

3. **Activate the tunnel**
   - Click **Activate** in the app

4. **Verify connection** (optional)
   ```bash
   # Linux/Mac:
   curl https://ifconfig.me

   # Windows PowerShell:
   Invoke-RestMethod https://ifconfig.me
   ```
   This should return your server's public IP, not your local IP.

---

### 🔧 Manual Setup (Advanced)

If you prefer manual setup without using the scripts:

<details>
<summary>Click to expand manual instructions</summary>

#### Generate client keys locally

```bash
wg genkey | tee client_private.key | wg pubkey > client_public.key
```

#### Create client config file

```ini
[Interface]
PrivateKey = <contents of client_private.key>
Address    = 10.100.0.2/24
DNS        = 1.1.1.1

[Peer]
PublicKey  = <run: ssh azureuser@<vm_ip> 'sudo cat /etc/wireguard/server_public.key'>
Endpoint   = <vm_public_ip>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

#### Register the client on the server

```bash
ssh azureuser@<vm_public_ip> \
  "sudo wg set wg0 peer $(cat client_public.key) allowed-ips 10.100.0.2/32"

ssh azureuser@<vm_public_ip> \
  "sudo wg-quick save wg0"
```

</details>

---

### 📝 Managing Multiple Clients

Each client needs a unique IP address. Use different IPs in the `10.100.0.0/24` range:

**Linux / Mac:**
```bash
# Client 1 (laptop):
./scripts/setup-client.sh <vm_ip> laptop 10.100.0.2

# Client 2 (phone):
./scripts/setup-client.sh <vm_ip> phone 10.100.0.3

# Client 3 (tablet):
./scripts/setup-client.sh <vm_ip> tablet 10.100.0.4
```

**Windows (PowerShell):**
```powershell
# Client 1 (laptop):
.\scripts\setup-client.ps1 -ServerIP <vm_ip> -ClientName laptop -ClientIP 10.100.0.2

# Client 2 (phone):
.\scripts\setup-client.ps1 -ServerIP <vm_ip> -ClientName phone -ClientIP 10.100.0.3

# Client 3 (tablet):
.\scripts\setup-client.ps1 -ServerIP <vm_ip> -ClientName tablet -ClientIP 10.100.0.4
```

To view connected clients on the server:

**Linux / Mac:**
```bash
ssh azureuser@<vm_ip> 'sudo wg show'
```

**Windows (PowerShell):**
```powershell
ssh azureuser@<vm_ip> 'sudo wg show'
```

---

## Teardown

```bash
cd terraform/
terraform destroy
```

This deletes all resources including the Resource Group.

---

## Extending to Another Cloud Provider

To add, for example, AWS:

1. Create `terraform/modules/aws/` with the same variable/output interface:
   - **Variables:** `project_name`, `environment`, `region`, `instance_type`,
     `admin_username`, `ssh_public_key`, `allowed_ssh_cidr`,
     `wireguard_port`, `wireguard_server_address`
   - **Outputs:** `vm_public_ip`, `ssh_command`, `wireguard_public_key_command`

2. Add the provider to `terraform/providers.tf`:
   ```hcl
   aws = {
     source  = "hashicorp/aws"
     version = "~> 5.0"
   }
   ```

3. Add a module block in `terraform/main.tf`:
   ```hcl
   module "aws" {
     count  = var.cloud == "aws" ? 1 : 0
     source = "./modules/aws"
     # ... map variables
   }
   ```

4. Wire the new module into `terraform/outputs.tf` using the same pattern.

5. Add AWS-specific variables to `terraform/variables.tf` (prefixed `aws_`).

6. Update the `cloud` variable validation to include `"aws"`.

---

## State Management

State is stored locally (`terraform.tfstate`) by default.

For team use, migrate to remote state by adding a `backend` block in
`terraform/providers.tf`. Example for Azure Blob Storage:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate"
  storage_account_name = "sttfstate<unique>"
  container_name       = "tfstate"
  key                  = "wireguard.tfstate"
}
```

---

## Resource Naming Convention

All Azure resources follow this pattern:

```
<type-prefix>-<project_name>-<environment>
```

Examples with defaults (`project_name=wireguard`, `environment=dev`):

| Resource | Name |
|---|---|
| Resource Group | `rg-wireguard-dev` |
| Virtual Network | `vnet-wireguard-dev` |
| Subnet | `snet-wireguard-dev` |
| NSG | `nsg-wireguard-dev` |
| Public IP | `pip-wireguard-dev` |
| NIC | `nic-wireguard-dev` |
| VM | `vm-wireguard-dev` |
