<#
.SYNOPSIS
    WireGuard configuration QR code display script (for Windows)

.DESCRIPTION
    Displays a QR code that can be scanned by a smartphone.

.PARAMETER ServerIP
    The IP address of the WireGuard server.

.PARAMETER ClientName
    The name of the client.

.PARAMETER Username
    The username for SSH connection (Default: azureuser).

.EXAMPLE
    .\show-qr.ps1 -ServerIP "20.123.45.67" -ClientName "my-iphone"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ServerIP,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$ClientName,

    [Parameter(Mandatory=$false)]
    [string]$Username = "azureuser"
)

$ErrorActionPreference = "Stop"

# Check for SSH command
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "Error: SSH command not found" -ForegroundColor Red
    Write-Host "Please install OpenSSH:" -ForegroundColor Yellow
    Write-Host "  Settings -> Apps -> Optional features -> OpenSSH Client" -ForegroundColor Yellow
    exit 1
}

Write-Host "Connecting to server to display QR code..." -ForegroundColor Yellow
Write-Host ""

try {
    # Generate and display QR code on server
    $Command = @"
if ! command -v qrencode &> /dev/null; then
    echo 'Installing qrencode...'
    apt-get update -qq && apt-get install -y qrencode
fi

if [ ! -f /etc/wireguard/${ClientName}.conf ]; then
    echo 'Error: Configuration file not found: /etc/wireguard/${ClientName}.conf'
    exit 1
fi

echo '=== QR Code for ${ClientName} ==='
echo ''
cat /etc/wireguard/${ClientName}.conf | qrencode -t ansiutf8
echo ''
echo 'Please scan this with the WireGuard app by selecting + -> Create from QR code'
"@

    ssh -t "$Username@$ServerIP" "sudo bash -c '$Command'"

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to display QR code"
    }

} catch {
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Verify if the client name is correct: $ClientName" -ForegroundColor White
    Write-Host "2. Create the client configuration first:" -ForegroundColor White
    Write-Host "   .\setup-client.ps1 -ServerIP $ServerIP -ClientName $ClientName" -ForegroundColor Cyan
    Write-Host "3. Manually connect to the server and check for the file:" -ForegroundColor White
    Write-Host "   ssh $Username@$ServerIP 'sudo ls -la /etc/wireguard/*.conf'" -ForegroundColor Cyan
    exit 1
}
