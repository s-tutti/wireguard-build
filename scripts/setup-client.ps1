<#
.SYNOPSIS
    WireGuard client automatic setup script (for Windows)

.DESCRIPTION
    Run this script in Windows PowerShell to automate WireGuard client configuration.
    It connects to the server via SSH, generates the client configuration, and downloads it.

.PARAMETER ServerIP
    The IP address of the WireGuard server.

.PARAMETER ClientName
    The name of the client (Default: Computer Name).

.PARAMETER ClientIP
    The VPN internal IP address for the client (Default: Auto-assigned).

.PARAMETER Username
    The username for SSH connection (Default: azureuser).

.EXAMPLE
    .\setup-client.ps1 -ServerIP "20.123.45.67"

.EXAMPLE
    .\setup-client.ps1 -ServerIP "20.123.45.67" -ClientName "my-laptop" -ClientIP "10.100.0.3"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ServerIP,

    [Parameter(Mandatory=$false)]
    [string]$ClientName = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [string]$ClientIP = $null,

    [Parameter(Mandatory=$false)]
    [string]$Username = "azureuser"
)

$ErrorActionPreference = "Stop"

$DisplayIP = if ($null -eq $ClientIP -or $ClientIP -eq "") { "Auto-assigned" } else { $ClientIP }

Write-Host "=== WireGuard Client Automatic Setup ===" -ForegroundColor Cyan
Write-Host "Server IP: $ServerIP" -ForegroundColor White
Write-Host "Client Name: $ClientName" -ForegroundColor White
Write-Host "Client IP: $DisplayIP" -ForegroundColor White
Write-Host ""

# Check for SSH command
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "Error: SSH command not found" -ForegroundColor Red
    Write-Host "Please install OpenSSH:" -ForegroundColor Yellow
    Write-Host "  Settings -> Apps -> Optional features -> OpenSSH Client" -ForegroundColor Yellow
    exit 1
}

# Check for SCP command
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
    Write-Host "Error: SCP command not found" -ForegroundColor Red
    Write-Host "Please install OpenSSH" -ForegroundColor Yellow
    exit 1
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddClientScript = Join-Path $ScriptDir "add-client.sh"

# Check for existence of add-client.sh
if (-not (Test-Path $AddClientScript)) {
    Write-Host "Error: add-client.sh not found: $AddClientScript" -ForegroundColor Red
    exit 1
}

try {
    # [1/3] Upload script to server
    Write-Host "[1/3] Uploading script to server..." -ForegroundColor Yellow
    ssh "$Username@$ServerIP" "mkdir -p ~/wireguard-scripts" 2>$null
    scp "$AddClientScript" "${Username}@${ServerIP}:~/wireguard-scripts/" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload script"
    }

    # [2/3] Execute client addition script on server
    Write-Host "[2/3] Running client configuration on server..." -ForegroundColor Yellow
    ssh "$Username@$ServerIP" "sudo bash ~/wireguard-scripts/add-client.sh '$ClientName' '$ClientIP'"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to execute script on server"
    }

    # [3/3] Download configuration file
    Write-Host "[3/3] Downloading configuration file..." -ForegroundColor Yellow

    # Create destination directory
    $ConfigDir = Join-Path $env:USERPROFILE "wireguard-configs"
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }

    $ConfigFile = Join-Path $ConfigDir "${ClientName}.conf"
    ssh "${Username}@${ServerIP}" "sudo cat /etc/wireguard/${ClientName}.conf" | Set-Content -Path "$ConfigFile" -Encoding Ascii
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download configuration file"
    }

    Write-Host ""
    Write-Host "✓ Setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== Configuration File ===" -ForegroundColor Cyan
    Write-Host "$ConfigFile" -ForegroundColor White
    Write-Host ""
    Write-Host "=== Next Steps ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[Setup in WireGuard App]" -ForegroundColor Yellow
    Write-Host "1. Install WireGuard (if not already installed):" -ForegroundColor White
    Write-Host "   https://www.wireguard.com/install/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Launch WireGuard app" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Click 'Add Tunnel' -> 'Import tunnel(s) from file'" -ForegroundColor White
    Write-Host ""
    Write-Host "4. Select the following file:" -ForegroundColor White
    Write-Host "   $ConfigFile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "5. Click 'Activate' to connect" -ForegroundColor White
    Write-Host ""
    Write-Host "[Connection Verification]" -ForegroundColor Yellow
    Write-Host "After connecting, verify that the server's IP address is displayed:" -ForegroundColor White
    Write-Host "   Invoke-RestMethod https://ifconfig.me" -ForegroundColor Cyan
    Write-Host ""

    # Check if WireGuard is installed
    $WireGuardPath = "C:\Program Files\WireGuard\wireguard.exe"
    if (Test-Path $WireGuardPath) {
        Write-Host "[Quick Import]" -ForegroundColor Yellow
        Write-Host "WireGuard detected. Would you like to import it now?" -ForegroundColor White
        $Response = Read-Host "[Y/N]"
        if ($Response -eq "Y" -or $Response -eq "y") {
            Write-Host "Importing configuration into WireGuard app..." -ForegroundColor Yellow
            & $WireGuardPath /installtunnelservice "$ConfigFile"
            Write-Host "✓ Import complete! Please click 'Activate' in the WireGuard app." -ForegroundColor Green
        }
    }

} catch {
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check if the server IP address is correct" -ForegroundColor White
    Write-Host "2. Check if SSH key authentication is configured" -ForegroundColor White
    Write-Host "3. Check if you can connect manually via SSH:" -ForegroundColor White
    Write-Host "   ssh $Username@$ServerIP" -ForegroundColor Cyan
    exit 1
}
