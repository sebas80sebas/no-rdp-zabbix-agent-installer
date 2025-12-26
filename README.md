# Zabbix Agent Installation on Azure Windows VMs

## Overview
This project demonstrates how to install and configure the Zabbix Agent on Windows virtual machines in Azure using the **Run Command** feature, without requiring RDP access or login credentials.

## Use Case
When you need to deploy monitoring agents to Windows VMs but:
- Don't have RDP credentials
- Want to automate the deployment
- Need to manage multiple VMs at scale
- Prefer using Azure's native management tools

## Prerequisites
- Azure subscription with appropriate permissions
- Access to Azure Portal or Azure CLI
- Target Windows VM(s) running in Azure
- Zabbix Server already deployed and accessible

## Solution Architecture
This solution uses Azure's **Run Command** feature to execute PowerShell scripts directly on the target VM without requiring authentication or remote desktop access.

## Installation Script

> **Note:** For testing purposes, you can add `ping www.google.com` at the beginning of the script to verify internet connectivity before attempting the download.

The script performs the following actions:
1. Creates a temporary directory for the installation files
2. Downloads the Zabbix Agent installer from the official CDN
3. Installs the agent with custom configuration parameters
4. Verifies the service installation

## Configuration Parameters

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| `$ResourceGroup` | Azure resource group name | `"monitoring-rg"` |
| `$VMname` | Target virtual machine name | `"win-server-01"` |
| `$ZabbixIP` | Zabbix Server IP address | `"10.8.2.4"` |
| `SERVER` | Zabbix Server for passive checks | Same as $ZabbixIP |
| `SERVERACTIVE` | Zabbix Server for active checks | Same as $ZabbixIP |
| `HOSTNAME` | Agent hostname (auto-detected) | `$env:COMPUTERNAME` |
| `LISTENPORT` | Agent listening port | `10050` |

## Deployment Methods

### Method 1: Azure Portal

1. Navigate to your Windows VM in Azure Portal
2. Go to **Operations** > **Run command**
3. Select **RunPowerShellScript**
4. Paste the script content (after updating variables)
5. Click **Run**
6. Wait for execution to complete
7. Review the output

### Method 2: Azure CLI

```bash
az vm run-command invoke \
  --resource-group YOUR_RESOURCE_GROUP \
  --name YOUR_VM_NAME \
  --command-id RunPowerShellScript \
  --scripts @install-zabbix-agent.ps1
```

### Method 3: Azure PowerShell

```powershell
Invoke-AzVMRunCommand `
  -ResourceGroupName 'YOUR_RESOURCE_GROUP' `
  -VMName 'YOUR_VM_NAME' `
  -CommandId 'RunPowerShellScript' `
  -ScriptPath './install-zabbix-agent.ps1'
```

## Verification

After installation, verify the agent is running:

```powershell
Get-Service 'Zabbix Agent'
```

Expected output:
```
Status   Name               DisplayName
------   ----               -----------
Running  Zabbix Agent       Zabbix Agent
```

Check the installation log:
```powershell
Get-Content C:\Temp\zabbix_install.log
```

## Firewall Configuration

Ensure the Windows Firewall allows inbound connections on port 10050:

```powershell
New-NetFirewallRule -DisplayName "Zabbix Agent" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 10050 `
  -Action Allow
```

## Network Security Group (NSG)

If using Azure NSG, add an inbound rule:
- **Source**: Zabbix Server IP
- **Destination**: VM IP
- **Port**: 10050
- **Protocol**: TCP
- **Action**: Allow

## Troubleshooting

### Testing Internet Connectivity
Before running the full installation, you can test if the VM has internet access:

```powershell
ping www.google.com
```

Add this line at the beginning of the script if you want to verify connectivity before attempting to download the installer.

### Agent Not Starting
- Check the installation log: `C:\Temp\zabbix_install.log`
- Verify Zabbix Server IP is correct
- Ensure network connectivity between VM and Zabbix Server

### Connection Issues
- Verify firewall rules (Windows Firewall and NSG)
- Test connectivity: `Test-NetConnection -ComputerName ZABBIX_IP -Port 10050`
- Check Zabbix Server logs for connection attempts

### Service Not Found
- Verify the installation completed successfully
- Check if the MSI downloaded correctly
- Review Run Command output for errors

## Security Considerations

- Use Azure Private Link for internal network communication
- Implement NSG rules to restrict access to Zabbix Server only
- Consider using TLS/PSK encryption for agent-server communication
- Regularly update the Zabbix Agent version
- Store sensitive values in Azure Key Vault (for production deployments)

## Benefits of This Approach

**No credentials required** - Uses Azure's management plane authentication  
**Agentless deployment** - No need for RDP or WinRM access  
**Scalable** - Can be applied to multiple VMs simultaneously  
**Auditable** - All actions logged in Azure Activity Log  
**Secure** - Leverages Azure RBAC for access control

## Deployment Without Internet Connectivity

If your Windows VMs don't have internet access, you can host the Zabbix Agent installer in Azure Storage and use Run Command to download it directly from there.

### Prerequisites for Offline Installation
- Azure Storage Account in the same region as your VMs
- Zabbix Agent MSI installer file downloaded from [Zabbix Downloads](https://www.zabbix.com/download_agents)
- Azure CLI or Azure Portal access

### Step 1: Create Storage Account and Upload Installer

Using Azure CLI:

```bash
# Create Storage Account
az storage account create \
  --name zabbixinstallers \
  --resource-group monitoring-rg \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2

# Create container with public blob access
az storage container create \
  --name installers \
  --account-name zabbixinstallers \
  --public-access blob

# Upload the Zabbix Agent MSI file
az storage blob upload \
  --account-name zabbixinstallers \
  --container-name installers \
  --name zabbix_agent-7.0.0-windows-amd64-openssl.msi \
  --file zabbix_agent-7.0.0-windows-amd64-openssl.msi

# Get the public URL (no expiration)
az storage blob url \
  --account-name zabbixinstallers \
  --container-name installers \
  --name zabbix_agent-7.0.0-windows-amd64-openssl.msi \
  --output tsv
```

The URL will be something like:
```
https://zabbixinstallers.blob.core.windows.net/installers/zabbix_agent-7.0.0-windows-amd64-openssl.msi
```

### Step 2: Installation Script for Offline Deployment

Save this as `install-zabbix-agent-offline.ps1`:

```powershell
# ============================================
# Zabbix Agent Installation Script
# Uses Azure Storage Account (no internet required)
# ============================================

# Configuration Variables
$ZabbixIP = "10.8.2.4"  # Zabbix Server/Proxy IP
$InstallerUrl = "https://zabbixinstallers.blob.core.windows.net/installers/zabbix_agent-7.0.0-windows-amd64-openssl.msi"
$TempDir = "C:\Temp"
$InstallerPath = "$TempDir\zabbix_agent.msi"
$LogFile = "$TempDir\zabbix_install.log"

# Create temporary directory
Write-Host "Creating temporary directory..."
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# Download installer from Azure Storage
Write-Host "Downloading Zabbix Agent from Azure Storage..."
try {
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing
    Write-Host "Download completed successfully"
} catch {
    Write-Error "Error downloading installer: $_"
    exit 1
}

# Verify file was downloaded
if (!(Test-Path $InstallerPath)) {
    Write-Error "Installer file not found at $InstallerPath"
    exit 1
}

# Install Zabbix Agent
Write-Host "Installing Zabbix Agent..."
$InstallArgs = "/i `"$InstallerPath`" /qn /l*v `"$LogFile`" SERVER=$ZabbixIP SERVERACTIVE=$ZabbixIP HOSTNAME=$env:COMPUTERNAME LISTENPORT=10050"

try {
    Start-Process msiexec.exe -Wait -ArgumentList $InstallArgs -NoNewWindow
    Write-Host "Installation completed"
} catch {
    Write-Error "Error during installation: $_"
    exit 1
}

# Configure Windows Firewall
Write-Host "Configuring firewall rule..."
try {
    New-NetFirewallRule -DisplayName "Zabbix Agent" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 10050 `
        -Action Allow `
        -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Firewall rule configured"
} catch {
    Write-Warning "Could not create firewall rule: $_"
}

# Verify service installation
Write-Host "`nVerifying installation..."
$Service = Get-Service -Name "Zabbix Agent" -ErrorAction SilentlyContinue

if ($Service) {
    Write-Host "Service status: $($Service.Status)"
    
    if ($Service.Status -ne "Running") {
        Write-Host "Starting service..."
        Start-Service -Name "Zabbix Agent"
        Start-Sleep -Seconds 2
        $Service = Get-Service -Name "Zabbix Agent"
        Write-Host "Current status: $($Service.Status)"
    }
} else {
    Write-Error "Zabbix Agent service not found"
}

# Display final information
Write-Host "`n=== Installation Completed ==="
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "Zabbix Server/Proxy: $ZabbixIP"
Write-Host "Listen Port: 10050"
Write-Host "Installation Log: $LogFile"
```

### Step 3: Deploy Using Azure Run Command

**Single VM Deployment:**

```bash
az vm run-command invoke \
  --resource-group monitoring-rg \
  --name win-agent-01 \
  --command-id RunPowerShellScript \
  --scripts @install-zabbix-agent-offline.ps1
```

**Multiple VMs Deployment (Bash):**

Save as `deploy-multiple-vms.sh`:

```bash
#!/bin/bash

# Configuration
RESOURCE_GROUP="monitoring-rg"
VMS=("win-agent-01" "win-agent-02" "win-agent-03")

echo "=== Deploying Zabbix Agent to Multiple VMs ==="
echo ""

for VM in "${VMS[@]}"; do
    echo "Installing on VM: $VM"
    
    az vm run-command invoke \
      --resource-group $RESOURCE_GROUP \
      --name $VM \
      --command-id RunPowerShellScript \
      --scripts @install-zabbix-agent-offline.ps1 \
      --output table
    
    echo "----------------------------------------"
    echo ""
done

echo "=== Deployment Completed ==="
```

**Multiple VMs Deployment (PowerShell):**

Save as `deploy-multiple-vms.ps1`:

```powershell
# Configuration
$ResourceGroup = "monitoring-rg"
$VMs = @("win-agent-01", "win-agent-02", "win-agent-03")
$ScriptPath = "./install-zabbix-agent-offline.ps1"

Write-Host "=== Deploying Zabbix Agent to Multiple VMs ===" -ForegroundColor Green
Write-Host ""

foreach ($VM in $VMs) {
    Write-Host "Installing on VM: $VM" -ForegroundColor Yellow
    
    try {
        Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroup `
            -VMName $VM `
            -CommandId 'RunPowerShellScript' `
            -ScriptPath $ScriptPath
        
        Write-Host "✓ Installation completed on $VM" -ForegroundColor Green
    } catch {
        Write-Host "✗ Error on $VM : $_" -ForegroundColor Red
    }
    
    Write-Host "----------------------------------------"
    Write-Host ""
}

Write-Host "=== Deployment Completed ===" -ForegroundColor Green
```

### Benefits of Azure Storage Approach

- **No expiration** - The installer URL remains accessible indefinitely
- **No internet required** - VMs only need access to Azure Storage endpoints
- **Fast deployment** - Download from Azure datacenter (low latency)
- **Scalable** - Deploy to unlimited number of VMs
- **Version control** - Upload different versions with different names
- **Cost-effective** - Minimal storage costs (few cents per month)

### Network Requirements

Ensure your VMs can reach Azure Storage endpoints. Add NSG rules if needed:

**Outbound Rule:**
- **Destination**: Service Tag `Storage`
- **Port**: 443 (HTTPS)
- **Protocol**: TCP
- **Action**: Allow

If using private networking, consider Azure Storage Service Endpoints or Private Endpoints for enhanced security.

## License

This script is provided as-is for educational and operational purposes.

## References

- [Zabbix Documentation](https://www.zabbix.com/documentation/current/)
- [Azure Run Command Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/run-command-overview)
- [Zabbix Agent Download](https://www.zabbix.com/download_agents)
- [Azure Storage Documentation](https://learn.microsoft.com/en-us/azure/storage/)
