targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@allowed([
  'Demo'
  'Dev'
  'Test'
  'Staging'
  'Prod'
])
param environmentName string = 'Prod'

@description('Address prefix for the virtual network.')
param net_RemoteDesktop_vnetAddressPrefix string = '10.100.40.0/21'

@description('Address prefix for the Azure Bastion subnet.')
param net_RemoteDesktop_bastionSubnetPrefix string = '10.100.40.0/26'

param net_RemoteDesktop_webSubnetPrefix string = '10.100.40.64/27'
param net_RemoteDesktop_appSubnetPrefix string = '10.100.40.96/27'
param net_RemoteDesktop_dbSubnetPrefix string = '10.100.40.128/27'
@description('Address prefix for the storage subnet, used with Azure Storage Accounts and FSLogix.')
param net_RemoteDesktop_storageSubnetPrefix string = '10.100.40.160/27'

param net_RemoteDesktop_webVNETIntegrationSubnetPrefix string = '10.100.40.192/27'

@description('Address prefix for the Remote Desktop Server subnet.')
param net_RemoteDesktop_rdServerSubnetPrefix string = '10.100.41.0/24'

@description('Address prefix for the first Azure Virtual Desktop subnet.')
param net_RemoteDesktop_avdSubnetPrefix string = '10.100.42.0/24'

@description('The private IP address of the Azure Firewall deployed in the hub, used as the next hop for forced tunneling from the Remote Desktop Server subnet.')
param net_hub_azureFirewallPrivateIP string = '10.100.0.4'

@description('The string array of DNS servers to use on the Virtual Network.')
param vNETDNSServers array = [
  '168.63.129.16'
]

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

@description('Tags applied to every resource.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── Resource Groups ───────────────────────────────────────────────────────────

@description('Spoke VNET resource group — contains the spoke Virtual Network (including Bastion subnet, Remote Desktop Server VM subnet, and AVD subnet for future AVD deployment)')
resource spokeVNETRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-Network-01'
  location: location
  tags: tags
}

// ── Resources ───────────────────────────────────────────────────────────
module networkingVirtualDesktop '../network/networking_virtualDesktop.bicep' = {
  name: 'virtualDesktopNetworking_${deploymentTimestamp}'
  scope: spokeVNETRG
  params: {
    location: location
    environmentName: environmentName
    vnetAddressPrefix: net_RemoteDesktop_vnetAddressPrefix
    bastionSubnetPrefix: net_RemoteDesktop_bastionSubnetPrefix
    webSubnetPrefix: net_RemoteDesktop_webSubnetPrefix
    appSubnetPrefix: net_RemoteDesktop_appSubnetPrefix
    dbSubnetPrefix: net_RemoteDesktop_dbSubnetPrefix
    storageSubnetPrefix: net_RemoteDesktop_storageSubnetPrefix
    webVNETIntegrationSubnetPrefix: net_RemoteDesktop_webVNETIntegrationSubnetPrefix
    rdServerSubnetPrefix: net_RemoteDesktop_rdServerSubnetPrefix
    avdSubnetPrefix: net_RemoteDesktop_avdSubnetPrefix
    vNETDNSServers: vNETDNSServers
    azureFirewallPrivateIp: net_hub_azureFirewallPrivateIP
    tags: tags
  }
}

// ── Outputs ───────────────────────────────────────────────────────────
@description('The name of the Remote Desktop VNET Resource Group.')
output rdVnetResourceGroupName string = spokeVNETRG.name

@description('Remote Desktop VNET ID.')
output rdVnetId string = networkingVirtualDesktop.outputs.vnetId

@description('Remote Desktop VNET Name.')
output rdVnetName string = networkingVirtualDesktop.outputs.vnetName

@description('The Subnet ID of the Bastion Subnet within the Remote Desktop VNET.')
output bastionSubnetId string = networkingVirtualDesktop.outputs.AzureBastionSubnetId

@description('The Subnet ID of the Remote Desktop Server Subnet within the Remote Desktop VNET.')
output rdServerSubnetId string = networkingVirtualDesktop.outputs.RDServer01SubnetId

@description('The Subnet ID of the AVD Subnet within the Remote Desktop VNET.')
output avdSubnetId string = networkingVirtualDesktop.outputs.AVD01SubnetId
