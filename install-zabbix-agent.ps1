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
