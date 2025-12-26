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

The script performs the following actions:
1. Tests network connectivity to verify internet access
2. Creates a temporary directory for the installation files
3. Downloads the Zabbix Agent installer from the official CDN
4. Installs the agent with custom configuration parameters
5. Verifies the service installation

### Script: `install-zabbix-agent.ps1`

```powershell
# Configuration variables
$ResourceGroup = "YOUR_RESOURCE_GROUP"
$VMname = "YOUR_VM_NAME"
$ZabbixIP = "YOUR_ZABBIX_SERVER_IP"

$ZabbixServer = $ZabbixIP
$ServerActive = $ZabbixIP
$url = 'https://cdn.zabbix.com/zabbix/binaries/stable/7.4/7.4.6/zabbix_agent-7.4.6-windows-amd64-openssl.msi'
$output = "C:\Temp\zabbix_agent.msi"

# Create temp directory
New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null

# Download Zabbix Agent installer
Invoke-WebRequest -Uri $url -OutFile $output

# Installation arguments
$arguments = @(
    '/i', $output,
    '/qn',
    "SERVER=$ZabbixServer",
    "SERVERACTIVE=$ServerActive",
    "HOSTNAME=$env:COMPUTERNAME",
    'LISTENPORT=10050',
    'ENABLEPATH=1',
    '/l*v', 'C:\Temp\zabbix_install.log'
)

# Install Zabbix Agent
Start-Process msiexec.exe -ArgumentList $arguments -Wait -NoNewWindow

# Verify installation
Get-Service 'Zabbix Agent'
```

> **Note:** For testing purposes, you can add `ping www.google.com` at the beginning of the script to verify internet connectivity before attempting the download.

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

## License

This script is provided as-is for educational and operational purposes.

## References

- [Zabbix Documentation](https://www.zabbix.com/documentation/current/)
- [Azure Run Command Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/run-command-overview)
- [Zabbix Agent Download](https://www.zabbix.com/download_agents)
