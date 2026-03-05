# WireGuard on Cloud — Terraform

Terraform project that provisions a WireGuard VPN server on a cloud VM.
Azure is the first supported provider; the module structure makes adding
AWS, GCP, or others straightforward.

---

## Project Structure

```
.
├── .gitignore
├── README.md
└── terraform/
    ├── providers.tf                  # Provider requirements & backend (local state)
    ├── main.tf                       # Cloud module dispatch
    ├── variables.tf                  # All input variables (root)
    ├── outputs.tf                    # Unified outputs
    ├── terraform.tfvars.example      # Copy → terraform.tfvars and fill in values
    └── modules/
        └── azure/                    # Azure implementation
            ├── main.tf               # RG, VNet, NSG, Public IP, NIC, VM
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

```bash
# 1. Clone / enter the repo
cd terraform/

# 2. Create your variable file
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars          # fill in ssh_public_key and review other values

# 3. Initialize Terraform (downloads providers)
terraform init

# 4. Preview what will be created
terraform plan

# 5. Apply
terraform apply
```

After `apply` completes, Terraform prints:

```
vm_public_ip                 = "x.x.x.x"
wireguard_endpoint           = "x.x.x.x:51820"
ssh_command                  = "ssh azureuser@x.x.x.x"
wireguard_public_key_command = "ssh azureuser@x.x.x.x 'sudo cat /etc/wireguard/server_public.key'"
```

Cloud-init runs the WireGuard setup script in the background on first boot.
Wait ~2 minutes for it to finish, then retrieve the server public key:

```bash
# From the output above:
ssh azureuser@x.x.x.x 'sudo cat /etc/wireguard/server_public.key'

# Check setup log if something seems wrong:
ssh azureuser@x.x.x.x 'sudo cat /var/log/wireguard-setup.log'
```

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

After retrieving the server public key, configure a client like this:

```ini
# /etc/wireguard/wg0.conf  (or use the WireGuard GUI app)
[Interface]
PrivateKey = <client-private-key>
Address    = 10.100.0.2/24      # pick any unused IP in wireguard_server_address subnet
DNS        = 1.1.1.1

[Peer]
PublicKey  = <server-public-key>
Endpoint   = <vm_public_ip>:51820
AllowedIPs = 0.0.0.0/0          # route all traffic through VPN
             # use 10.100.0.0/24 to only route VPN subnet traffic
PersistentKeepalive = 25
```

Add the peer on the server:

```bash
# On your local machine, generate a client key pair:
wg genkey | tee client_private.key | wg pubkey > client_public.key

# On the server, add the peer:
ssh azureuser@<vm_public_ip> \
  "sudo wg set wg0 peer $(cat client_public.key) allowed-ips 10.100.0.2/32"

# Make the peer config persistent across reboots:
ssh azureuser@<vm_public_ip> \
  "sudo wg-quick save wg0"
```

---

## Connecting a Windows Client

### 1. Install WireGuard for Windows

Download and run the installer from [https://www.wireguard.com/install/](https://www.wireguard.com/install/).

### 2. Generate a client key pair

Open the WireGuard app and click **Add Tunnel → Create new tunnel**.
The app automatically generates a private/public key pair and displays them in the editor.

### 3. Enter the tunnel configuration

Replace the contents of the editor with the following (substitute the `<...>` placeholders with real values):

```ini
[Interface]
PrivateKey = <leave the auto-generated private key here>
Address    = 10.100.0.2/24
DNS        = 1.1.1.1

[Peer]
PublicKey  = <server-public-key>
Endpoint   = <vm_public_ip>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

- Retrieve the **server public key** after `terraform apply`:
  ```bash
  ssh azureuser@<vm_public_ip> 'sudo cat /etc/wireguard/server_public.key'
  ```
- `AllowedIPs = 0.0.0.0/0` routes all traffic through the VPN.
  Change to `10.100.0.0/24` to route only VPN subnet traffic.

### 4. Register the client public key on the server

Copy the **Public key** shown in the editor, then add it to the server:

```bash
ssh azureuser@<vm_public_ip> \
  "sudo wg set wg0 peer <client-public-key> allowed-ips 10.100.0.2/32"

ssh azureuser@<vm_public_ip> \
  "sudo wg-quick save wg0"
```

### 5. Connect

Back in the WireGuard app, click **Activate**.
Once the status shows **Active**, the tunnel is up.

Verify the connection:

```powershell
# Should return the server's public IP, not your local IP
Invoke-RestMethod https://ifconfig.me
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
